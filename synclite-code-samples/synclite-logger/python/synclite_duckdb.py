"""Python mirror of `synclite_duckdb.rs`.

Uses the DuckDB-backed connection. Same shape as the SQLite sample,
just `DuckDBConnection` instead of `Connection`.
"""

import synclite as sl

DB_PATH = "sample_duckdb.duckdb"
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
    sl.initialize(
        device_type="DUCKDB",
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

    conn = sl.DuckDBConnection.open(DB_PATH)

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
