//! Streaming device: append-only event ingestion. UPDATE / DELETE are
//! rejected by design — every event flows through the change log to the
//! configured destination.
//!
//! Defaults to a PostgreSQL destination; see the commented alternatives
//! below to switch to SQLite / DuckDB destinations, or to drop the
//! inline destination entirely and pair with a separate centralized
//! Consolidator service.

use synclite::{DeviceType, Result, Value};
use synclite::rusqlite::Connection;
use synclite::{DestinationOptions, DstSyncMode, DstType, SyncLiteOptions};

const DB_PATH: &str = "sample_streaming.db";
const DEVICE_NAME: &str = "sampledevice";

fn main() -> Result<()> {
    // PostgreSQL destination (default). Comment out and uncomment one
    // of the alternatives below for SQLite / DuckDB destinations, or
    // for the no-inline-destination path that pairs with a centralized
    // Consolidator service.
    synclite::initialize(
        DeviceType::STREAMING,
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
    //     DeviceType::STREAMING, DEVICE_NAME, DB_PATH,
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
    //     DeviceType::STREAMING, DEVICE_NAME, DB_PATH,
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
    //     DeviceType::STREAMING, DEVICE_NAME, DB_PATH, None,
    //     SyncLiteOptions::default(),
    // )?;

    let mut conn = Connection::open(DB_PATH)?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY, category TEXT, amount INTEGER)",
        &[],
    )?;

    {
        let mut stmt = conn.prepare("INSERT INTO events(id, category, amount) VALUES(?, ?, ?)")?;
        stmt.execute(&[Value::Int(1), Value::Text("stream".into()), Value::Int(40)])?;
        stmt.execute(&[Value::Int(2), Value::Text("stream".into()), Value::Int(60)])?;
    }

    // STREAMING devices accept INSERTs and DDL but reject UPDATE / DELETE.
    let update_err = conn
        .execute(
            "UPDATE events SET amount = ? WHERE id = ?",
            &[Value::Int(90), Value::Int(2)],
        )
        .expect_err("streaming should reject UPDATE");
    println!("UPDATE rejected: {update_err}");

    let delete_err = conn
        .execute("DELETE FROM events WHERE id = ?", &[Value::Int(1)])
        .expect_err("streaming should reject DELETE");
    println!("DELETE rejected: {delete_err}");

    conn.commit()?;

    // Force the active log segment to roll, then block until the
    // in-process shipper + consolidator have fully applied it to
    // PostgreSQL. Short-lived programs would otherwise exit before
    // the background pipeline gets to drain.
    conn.flush()?;
    synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30))?;
    conn.close()?;
    Ok(())
}
