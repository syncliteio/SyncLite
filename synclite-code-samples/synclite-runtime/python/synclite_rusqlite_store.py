"""Python mirror of `synclite_rusqlite_store.rs`.

STORE-device sample. The runtime is the system of record, so we open
the connection from a self-contained config file that carries
`device-type=SQLITE_STORE`.

See ../README.md for the `synclite` Python package install / setup.
"""

import os
import synclite as sl

DB_PATH = "sample_rusqlite_store_sqlite.db"
DEVICE_NAME = "sampledevice"
CONF_PATH = "sample_rusqlite_store.conf"
POSTGRES_CONN = "postgresql://postgres:postgres@localhost:5432/syncdb"


def write_conf() -> None:
    with open(CONF_PATH, "w", encoding="utf-8") as f:
        f.write(
            "device-name=sample-rusqlite-store\n"
            "db-engine=SQLITE\n"
            "device-type=SQLITE_STORE\n"
            f"db-path={DB_PATH}\n"
            "local-data-stage-directory=synclite-stage\n"
        )


def main() -> None:
    write_conf()

    # PostgreSQL destination (default). Comment out and uncomment one of
    # the alternatives below for SQLite / DuckDB destinations, or for
    # the no-inline-destination path that pairs with a centralized
    # Consolidator service.
    sl.initialize(
        device_type="SQLITE_STORE",
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
    #     device_type="SQLITE_STORE", device_name=DEVICE_NAME, db_path=DB_PATH,
    #     destination=sl.DestinationOptions(
    #         dst_type="SQLITE", dst_connection_string="dst_sqlite.db",
    #     ),
    # )

    # DuckDB destination example:
    # sl.initialize(
    #     device_type="SQLITE_STORE", device_name=DEVICE_NAME, db_path=DB_PATH,
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
    #     device_type="SQLITE_STORE", device_name=DEVICE_NAME, db_path=DB_PATH,
    #     config_path=CONF_PATH,
    # )

    conn = sl.Connection.open_with_config(CONF_PATH)

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
