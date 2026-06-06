//! Offline-first SQLite app that syncs every change to PostgreSQL.
//!
//! Run a local PostgreSQL with a database named `syncdb` and a schema
//! named `syncschema`, then:
//!
//!   cargo run --example synclite_rusqlite_postgres
//!
//! What you get:
//!   * a normal local SQLite database your app reads/writes through a
//!     rusqlite-style API — no network calls in the hot path,
//!   * an in-process consolidator that ships every committed change to
//!     PostgreSQL in the background,
//!   * `synclite::await_sync` to deterministically block until the
//!     in-flight segment has been applied to PostgreSQL.

use synclite::{DeviceType, Result, Value};
use synclite::rusqlite::Connection;
use synclite::{DestinationOptions, DstSyncMode, DstType, SyncLiteOptions};
use postgres::{Client, NoTls};

const DB_PATH: &str = "sample_rusqlite_sqlite.db";
const DEVICE_NAME: &str = "sampledevice";
const POSTGRES_URL: &str = "postgresql://postgres:postgres@localhost:5432/syncdb";
const POSTGRES_SCHEMA: &str = "syncschema";

fn read_row_from_postgres(id: i64) -> Result<Option<String>> {
    let mut client = Client::connect(POSTGRES_URL, NoTls)
        .map_err(|e| synclite::Error::Config(format!("failed to connect to PostgreSQL: {e}")))?;
    let query = format!(
        "SELECT row_to_json(t)::text FROM (SELECT * FROM {}.users WHERE id = $1) t",
        POSTGRES_SCHEMA
    );
    let row = client
        .query_opt(&query, &[&id])
        .map_err(|e| synclite::Error::Config(format!("failed to query PostgreSQL: {e}")))?;

    Ok(row.map(|r| r.get::<usize, String>(0)))
}

fn main() -> Result<()> {
    // One call wires up the local logger, the segment shipper, and the
    // embedded consolidator that drains into PostgreSQL.
    synclite::initialize(
        DeviceType::Sqlite,
        DEVICE_NAME,
        DB_PATH,
        Some(DestinationOptions {
            dst_type: DstType::Postgres,
            dst_connection_string:
                "postgresql://postgres:postgres@localhost:5432/syncdb".into(),
            dst_database: Some("syncdb".into()),
            dst_schema: Some("syncschema".into()),
            dst_sync_mode: DstSyncMode::Consolidation,
        }),
        SyncLiteOptions::default(),
    )?;

    // From here on the app talks to a plain local SQLite database.
    let mut conn = Connection::open(DB_PATH)?;

    conn.execute("DROP TABLE IF EXISTS users", &[])?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)",
        &[],
    )?;

    {
        let mut stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)")?;
        stmt.execute(&[Value::Int(1), Value::Text("Alice".into()), Value::Int(100)])?;
        stmt.execute(&[Value::Int(2), Value::Text("Bob".into()), Value::Int(200)])?;
    }

    conn.execute(
        "UPDATE users SET score = ? WHERE name = ?",
        &[Value::Int(250), Value::Text("Bob".into())],
    )?;
    conn.commit()?;

    {
        let mut stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)")?;
        stmt.add_batch(&[Value::Int(3), Value::Text("Carol".into()), Value::Int(300)]);
        stmt.add_batch(&[Value::Int(4), Value::Text("Dave".into()), Value::Int(400)]);
        stmt.execute_batch()?;
    }
    conn.commit()?;

    let rows = conn.query("SELECT id, name, score FROM users ORDER BY id", &[])?;
    for row in rows {
        println!("{:?}", row);
    }

    let local_rows = conn.query("SELECT * FROM users WHERE id = 4", &[])?;
    if let Some(row) = local_rows.first() {
        println!("[READ FROM LOCAL DB] {:?}", row);
    } else {
        println!("[READ FROM LOCAL DB] no row found for id=4");
    }

    // Force the active log segment to roll, then block until the
    // in-process shipper + consolidator have fully applied it to
    // PostgreSQL. Short-lived programs would otherwise exit before the
    // background pipeline gets to drain.
    conn.flush()?;
    match synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30)) {
        Ok(()) => {
            println!("[SYNC] await_sync succeeded");
            match read_row_from_postgres(4)? {
                Some(row) => println!("[READ FROM POSTGRESQL POST SYNC] {row}"),
                None => println!("[READ FROM POSTGRESQL POST SYNC] no row found for id=4"),
            }
        }
        Err(e) => {
            println!("[SYNC] await_sync failed: {e}");
            conn.close()?;
            return Err(e);
        }
    }

    conn.close()?;
    Ok(())
}
