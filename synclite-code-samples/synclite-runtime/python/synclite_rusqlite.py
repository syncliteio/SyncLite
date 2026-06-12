"""Python mirror of `synclite_rusqlite.rs`.

Drives the SyncLite Rust runtime via the `synclite` Python package —
no JVM, no JAR, no DB-API adapter. The `Connection` / `Statement`
objects below match the Rust and C++ samples one-for-one.

See ../README.md for the package install / setup.
"""

import synclite as sl

DB_PATH = "sample_rusqlite_sqlite.db"
DEVICE_NAME = "sampledevice"
POSTGRES_CONN = "postgresql://postgres:postgres@localhost:5432/syncdb"


def read_row_from_postgres(row_id: int) -> str | None:
    try:
        import psycopg

        with psycopg.connect(POSTGRES_CONN) as pg:
            with pg.cursor() as cur:
                cur.execute(
                    "SELECT row_to_json(t)::text FROM (SELECT * FROM syncschema.users WHERE id = %s) t",
                    (row_id,),
                )
                row = cur.fetchone()
                return row[0] if row else None
    except Exception as exc:
        print(f"[READ FROM POSTGRESQL POST SYNC] skipped: {exc}")
        return None


def main() -> None:
    # PostgreSQL destination (default). Comment out and uncomment one of
    # the alternatives below for SQLite / DuckDB destinations, or for
    # the no-inline-destination path that pairs with a centralized
    # Consolidator service.
    sl.initialize(
        device_type="SQLITE",
        device_name=DEVICE_NAME,
        db_path=DB_PATH,
        destination=sl.DestinationOptions(
            dst_type="POSTGRES",
            dst_connection_string=POSTGRES_CONN,
            dst_database="syncdb",
            dst_schema="syncschema",
            dst_sync_mode="CONSOLIDATION",
        ),
    )

    # SQLite destination example:
    # sl.initialize(
    #     device_type="SQLITE", device_name=DEVICE_NAME, db_path=DB_PATH,
    #     destination=sl.DestinationOptions(
    #         dst_type="SQLITE", dst_connection_string="dst_sqlite.db",
    #     ),
    # )

    # DuckDB destination example:
    # sl.initialize(
    #     device_type="SQLITE", device_name=DEVICE_NAME, db_path=DB_PATH,
    #     destination=sl.DestinationOptions(
    #         dst_type="DUCKDB",
    #         dst_connection_string="dst_duckdb.duckdb",
    #         dst_database="dst_duckdb",
    #         dst_schema="main",
    #     ),
    # )

    # Centralized Consolidator path — no inline destination. The device
    # only logs locally; a separate standalone Consolidator service
    # reads the log segments from staging storage and applies them to
    # the configured destination(s):
    # sl.initialize(
    #     device_type="SQLITE", device_name=DEVICE_NAME, db_path=DB_PATH,
    # )

    conn = sl.Connection.open(DB_PATH)

    conn.execute("DROP TABLE IF EXISTS users")
    conn.execute(
        "CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)"
    )

    stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)")
    stmt.execute([1, "Alice", 100])
    stmt.execute([2, "Bob",   200])

    conn.execute("UPDATE users SET score = ? WHERE name = ?", [250, "Bob"])
    conn.commit()

    stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)")
    stmt.add_batch([3, "Carol", 300])
    stmt.add_batch([4, "Dave",  400])
    stmt.execute_batch()
    conn.commit()

    for row in conn.query("SELECT id, name, score FROM users ORDER BY id"):
        print(row)

    local_rows = conn.query("SELECT * FROM users WHERE id = 4")
    print(f"[READ FROM LOCAL DB] {local_rows[0] if local_rows else None}")

    # Force the active log segment to roll, then block until the
    # in-process shipper + consolidator have fully applied it to
    # PostgreSQL. Short-lived programs would otherwise exit before
    # the background pipeline gets to drain.
    conn.flush()
    try:
        sl.await_sync(DB_PATH, 30.0)
        print("[SYNC] await_sync succeeded")
        pg_row = read_row_from_postgres(4)
        if pg_row is None:
            print("[READ FROM POSTGRESQL POST SYNC] no row found for id=4")
        else:
            print(f"[READ FROM POSTGRESQL POST SYNC] {pg_row}")
    except Exception as exc:
        print(f"[SYNC] await_sync failed: {exc}")

    conn.close()


if __name__ == "__main__":
    main()
