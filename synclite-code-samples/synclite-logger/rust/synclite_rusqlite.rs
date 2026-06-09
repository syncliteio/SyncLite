//! Offline-first local SQLite device using SyncLite.
//!
//! Same canonical shape as `synclite_rusqlite_postgres.rs`, but without
//! a remote destination — every write still produces a durable change
//! log on disk, ready to be consolidated to PostgreSQL / DuckDB / SQLite
//! whenever you wire up a destination (see the commented block below).

use synclite::{DeviceType, Result, Value};
use synclite::rusqlite::Connection;
use synclite::SyncLiteOptions;

const DB_PATH: &str = "sample_rusqlite_local.db";
const DEVICE_NAME: &str = "sampledevice";

fn main() -> Result<()> {
    synclite::initialize(
        DeviceType::SQLITE,
        DEVICE_NAME,
        DB_PATH,
        None, // local-only; see synclite_rusqlite_postgres.rs for the PG variant
        SyncLiteOptions::default(),
    )?;

    // To ship to PostgreSQL instead, replace the `None` above with:
    //
    // Some(synclite::DestinationOptions {
    //     dst_type: synclite::DstType::Postgres,
    //     dst_connection_string:
    //         "postgresql://postgres:postgres@localhost:5432/syncdb".into(),
    //     dst_database: Some("syncdb".into()),
    //     dst_schema: Some("syncschema".into()),
    //     dst_sync_mode: synclite::DstSyncMode::Consolidation,
    // })

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

    let rows = conn.query("SELECT id, name, score FROM users ORDER BY id", &[])?;
    for row in rows {
        println!("{:?}", row);
    }

    conn.flush()?;
    synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30))?;
    conn.close()?;
    Ok(())
}
