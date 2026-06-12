"""Python mirror of `synclite_duckdb_store.rs`.

DUCKDB_STORE device: bulk-friendly variant of the DuckDB sample. Same
DuckDB-backed `DuckDBConnection` API; only `device_type` differs.

See ../README.md for the `synclite` Python package install / setup.
"""

import synclite as sl

DB_PATH = "sample_duckdb_store.db"
DEVICE_NAME = "sampledevicestore"
POSTGRES_CONN = "postgresql://postgres:postgres@localhost:5432/syncdb"


def main() -> None:
    # PostgreSQL destination (default). Comment out and uncomment one of
    # the alternatives below for SQLite / DuckDB destinations, or for
    # the no-inline-destination path that pairs with a centralized
    # Consolidator service.
    sl.initialize(
        device_type="DUCKDB_STORE",
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
    #     device_type="DUCKDB_STORE", device_name=DEVICE_NAME, db_path=DB_PATH,
    #     destination=sl.DestinationOptions(
    #         dst_type="SQLITE", dst_connection_string="dst_sqlite.db",
    #     ),
    # )

    # DuckDB destination example:
    # sl.initialize(
    #     device_type="DUCKDB_STORE", device_name=DEVICE_NAME, db_path=DB_PATH,
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
    #     device_type="DUCKDB_STORE", device_name=DEVICE_NAME, db_path=DB_PATH,
    # )

    conn = sl.DuckDBConnection.open(DB_PATH)

    conn.execute("DROP TABLE IF EXISTS users")
    conn.execute(
        "CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)"
    )

    stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)")
    stmt.execute([1, "Alice", 100])
    stmt.execute([2, "Bob",   200])

    conn.execute("UPDATE users SET score = ? WHERE name = ?", [250, "Bob"])
    conn.execute("DELETE FROM users WHERE id = ?", [2])

    for row in conn.query("SELECT id, name, score FROM users ORDER BY id"):
        print(row)

    # Force the active log segment to roll, then block until the
    # in-process shipper + consolidator have fully applied it to
    # PostgreSQL. Short-lived programs would otherwise exit before
    # the background pipeline gets to drain.
    conn.flush()
    sl.await_sync(DB_PATH, 30.0)
    conn.close()


if __name__ == "__main__":
    main()
