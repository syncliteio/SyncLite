//! Reset a SyncLite device with `synclite::reinitialize`.
//!
//! Walks through:
//!  1. Initialize a SQLite device with a local SQLite destination.
//!  2. Write a couple of rows, flush, and await sync.
//!  3. Call `synclite::reinitialize(db, clean_destination=true)` to wipe
//!     per-device local state. Because the destination is configured in
//!     `REPLICATION` mode the user table is also dropped on the destination
//!     (in `CONSOLIDATION` mode it would be a safe no-op).
//!  4. Re-initialize the same logical device (same UUID, same device name)
//!     and write fresh rows to confirm the device comes back cleanly.
//!
//! For out-of-process control, drop one of these files alongside the
//! database and the next `synclite::initialize` will fire the reinit and
//! delete the trigger:
//!
//! ```text
//! reinitialize.<device-name>                          # preserve destination
//! reinitialize_with_clean_destination.<device-name>   # clean destination
//! ```

use synclite::{DeviceType, Result, Value};
use synclite::rusqlite::Connection;
use synclite::{DestinationOptions, DstSyncMode, DstType, SyncLiteOptions};

const DB_PATH: &str = "sample_reinit.db";
const DST_PATH: &str = "sample_reinit_dst.db";
const DEVICE_NAME: &str = "reinitdevice";

fn dest() -> DestinationOptions {
    DestinationOptions {
        dst_type: DstType::Sqlite,
        dst_connection_string: DST_PATH.into(),
        dst_database: None,
        dst_schema: None,
        dst_sync_mode: DstSyncMode::Replication,
    }
}

fn write_pair(label: &str, a: (i64, &str), b: (i64, &str)) -> Result<()> {
    let mut conn = Connection::open(DB_PATH)?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS items(id INTEGER PRIMARY KEY, name TEXT)",
        &[],
    )?;
    conn.execute(
        "INSERT INTO items(id, name) VALUES(?, ?)",
        &[Value::Int(a.0), Value::Text(a.1.into())],
    )?;
    conn.execute(
        "INSERT INTO items(id, name) VALUES(?, ?)",
        &[Value::Int(b.0), Value::Text(b.1.into())],
    )?;
    conn.commit()?;
    conn.flush()?;
    synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30))?;
    conn.close()?;
    println!("[{label}] wrote {:?} and {:?}", a, b);
    Ok(())
}

fn main() -> Result<()> {
    // Clean slate so the sample is rerunnable.
    let _ = std::fs::remove_file(DB_PATH);
    let _ = std::fs::remove_file(DST_PATH);
    let _ = std::fs::remove_dir_all(format!("{DB_PATH}.synclite"));

    synclite::initialize(
        DeviceType::Sqlite,
        DEVICE_NAME,
        DB_PATH,
        Some(dest()),
        SyncLiteOptions::default(),
    )?;
    write_pair("initial", (1, "alpha"), (2, "beta"))?;

    println!("[reset] reinitialize(clean_destination=true)");
    synclite::reinitialize(DB_PATH, true)?;

    // Same UUID, same device name — bring the device back up.
    synclite::initialize(
        DeviceType::Sqlite,
        DEVICE_NAME,
        DB_PATH,
        Some(dest()),
        SyncLiteOptions::default(),
    )?;
    write_pair("reseed", (10, "gamma"), (11, "delta"))?;

    Ok(())
}
