//! Offline-first local DuckDB device using SyncLite.
//!
//! Mirrors `synclite_rusqlite.rs` but with the DuckDB engine. Switch to
//! the DuckDb destination block in `synclite_rusqlite_postgres.rs` if you
//! want to ship to a remote DuckDB / PostgreSQL instance.

use synclite::{DeviceType, Result, Value};
use synclite::duckdb::Connection;
use synclite::SyncLiteOptions;

const DB_PATH: &str = "sample_duckdb.db";
const DEVICE_NAME: &str = "sampledevice";

fn main() -> Result<()> {
    synclite::initialize(
        DeviceType::DUCKDB,
        DEVICE_NAME,
        DB_PATH,
        None,
        SyncLiteOptions::default(),
    )?;

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
