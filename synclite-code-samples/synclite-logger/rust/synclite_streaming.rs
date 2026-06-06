//! Streaming device: append-only event ingestion. UPDATE / DELETE are
//! rejected by design — every event flows through the change log to the
//! configured destination.

use synclite::{DeviceType, Result, Value};
use synclite::rusqlite::Connection;
use synclite::SyncLiteOptions;

const DB_PATH: &str = "sample_streaming.db";
const DEVICE_NAME: &str = "sampledevice";

fn main() -> Result<()> {
    synclite::initialize(
        DeviceType::Streaming,
        DEVICE_NAME,
        DB_PATH,
        None,
        SyncLiteOptions::default(),
    )?;

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

    conn.flush()?;
    synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30))?;
    conn.close()?;
    Ok(())
}
