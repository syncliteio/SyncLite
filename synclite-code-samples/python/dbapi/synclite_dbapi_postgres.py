"""SyncLite Python DB-API 2.0 sample using PostgreSQL replication."""

import synclite as sl

try:
    from synclite import dbapi2
except ImportError as exc:
    raise ImportError(
        "This sample requires synclite 1.2.0 or newer, which exports "
        "synclite.dbapi2. Upgrade with: python -m pip install --upgrade "
        "synclite==1.2.0"
    ) from exc

DB_PATH = "sample_dbapi.db"
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
    conn = dbapi2.connect(DB_PATH)
    try:
        with conn:
            with conn.cursor() as cursor:
                cursor.execute("DROP TABLE IF EXISTS users")
                cursor.execute("CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)")
                cursor.executemany(
                    "INSERT INTO users(id, name, score) VALUES(?, ?, ?)",
                    [(1, "Alice", 100), (2, "Bob", 200), (3, "Carol", 300)],
                )
                cursor.execute("UPDATE users SET score = ? WHERE id = ?", (250, 2))
                cursor.execute("SELECT * FROM users ORDER BY id")
                print("[LOCAL]", cursor.fetchall())
        # The transaction commits when `with conn:` exits. Only then is it safe to
        # flush the active segment and wait for the external sync to complete.
        conn.flush()
        sl.await_sync(DB_PATH, 30.0)
        print("[SYNC] await_sync succeeded")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
