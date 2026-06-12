//! Offline-first local DuckDB device using SyncLite.
//!
//! Mirrors `synclite_rusqlite.rs` but with the DuckDB engine. Defaults
//! to a PostgreSQL destination; see the commented alternatives below to
//! switch to SQLite / DuckDB destinations, or to drop the inline
//! destination entirely and pair with a separate centralized
//! Consolidator service.

use synclite::{DeviceType, Result, Value};
use synclite::duckdb::Connection;
use synclite::{DestinationOptions, DstSyncMode, DstType, SyncLiteOptions};

const DB_PATH: &str = "sample_duckdb.db";
const DEVICE_NAME: &str = "sampledevice";

fn main() -> Result<()> {
    // PostgreSQL destination (default). Comment out and uncomment one
    // of the alternatives below for SQLite / DuckDB destinations, or
    // for the no-inline-destination path that pairs with a centralized
    // Consolidator service.
    synclite::initialize(
        DeviceType::DUCKDB,
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

    // SQLite destination example:
    // synclite::initialize(
    //     DeviceType::DUCKDB, DEVICE_NAME, DB_PATH,
    //     Some(DestinationOptions {
    //         dst_type: DstType::Sqlite,
    //         dst_connection_string: "dst_sqlite.db".into(),
    //         dst_database: None,
    //         dst_schema: None,
    //         dst_sync_mode: DstSyncMode::Consolidation,
    //     }),
    //     SyncLiteOptions::default(),
    // )?;

    // DuckDB destination example:
    // synclite::initialize(
    //     DeviceType::DUCKDB, DEVICE_NAME, DB_PATH,
    //     Some(DestinationOptions {
    //         dst_type: DstType::DuckDb,
    //         dst_connection_string: "dst_duckdb.duckdb".into(),
    //         dst_database: Some("dst_duckdb".into()),
    //         dst_schema: Some("main".into()),
    //         dst_sync_mode: DstSyncMode::Consolidation,
    //     }),
    //     SyncLiteOptions::default(),
    // )?;

    // Centralized Consolidator path — no inline destination. The device
    // only logs locally; a separate standalone Consolidator service
    // reads the log segments from staging storage and applies them to
    // the configured destination(s):
    // synclite::initialize(
    //     DeviceType::DUCKDB, DEVICE_NAME, DB_PATH, None,
    //     SyncLiteOptions::default(),
    // )?;

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

    // Force the active log segment to roll, then block until the
    // in-process shipper + consolidator have fully applied it to
    // PostgreSQL. Short-lived programs would otherwise exit before
    // the background pipeline gets to drain.
    conn.flush()?;
    synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30))?;
    conn.close()?;
    Ok(())
}
