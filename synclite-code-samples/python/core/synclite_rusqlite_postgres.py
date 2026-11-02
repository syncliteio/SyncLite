"""Core SyncLite Python API sample using the direct Rust-shaped API."""

import synclite as sl

DB_PATH = "sample_core.db"
DEVICE_NAME = "sampledevice"
POSTGRES_CONN = "postgresql://postgres:postgres@localhost:5432/syncdb"


def main() -> None:
    sl.initialize(
        device_type="SQLITE",
        device_name=DEVICE_NAME,
        db_path=DB_PATH,
        destination=sl.DestinationOptions(
            dst_type="POSTGRES",
            dst_connection_string=POSTGRES_CONN,
            dst_database="syncdb",
            dst_schema="syncschema",
            dst_sync_mode="REPLICATION",
        ),
    )
    conn = sl.Connection.open(DB_PATH)
    try:
        conn.execute("DROP TABLE IF EXISTS users")
        conn.execute("CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)")
        stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)")
        stmt.execute([1, "Alice", 100])
        stmt.add_batch([2, "Bob", 200])
        stmt.add_batch([3, "Carol", 300])
        stmt.execute_batch()
        conn.execute("UPDATE users SET score = ? WHERE id = ?", [250, 2])
        conn.commit()
        print("[LOCAL]", conn.query("SELECT * FROM users ORDER BY id"))

        # Roll the active segment and wait before closing this short-lived demo.
        conn.flush()
        sl.await_sync(DB_PATH, 30.0)
        print("[SYNC] await_sync succeeded")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
