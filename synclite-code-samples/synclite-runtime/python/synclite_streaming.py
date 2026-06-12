"""Python mirror of `synclite_streaming.rs`.

STREAMING-device sample. Same `Connection` API as the txn / store
samples; only `device-type` differs (configured in the conf file).

See ../README.md for the `synclite` Python package install / setup.
"""

import synclite as sl

DB_PATH = "sample_streaming_sqlite.db"
DEVICE_NAME = "sampledevice"
CONF_PATH = "sample_streaming.conf"
POSTGRES_CONN = "postgresql://postgres:postgres@localhost:5432/syncdb"


def write_conf() -> None:
    with open(CONF_PATH, "w", encoding="utf-8") as f:
        f.write(
            "device-name=sample-streaming\n"
            "db-engine=SQLITE\n"
            "device-type=STREAMING\n"
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
        device_type="STREAMING",
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
    #     device_type="STREAMING", device_name=DEVICE_NAME, db_path=DB_PATH,
    #     destination=sl.DestinationOptions(
    #         dst_type="SQLITE", dst_connection_string="dst_sqlite.db",
    #     ),
    # )

    # DuckDB destination example:
    # sl.initialize(
    #     device_type="STREAMING", device_name=DEVICE_NAME, db_path=DB_PATH,
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
    #     device_type="STREAMING", device_name=DEVICE_NAME, db_path=DB_PATH,
    #     config_path=CONF_PATH,
    # )

    conn = sl.Connection.open_with_config(CONF_PATH)

    conn.execute(
        "CREATE TABLE IF NOT EXISTS events("
        "  ts BIGINT, event_type TEXT, payload TEXT)"
    )

    stmt = conn.prepare("INSERT INTO events(ts, event_type, payload) VALUES(?, ?, ?)")
    stmt.execute([1714200000000, "SIGNUP", '{"user":"alice"}'])
    stmt.execute([1714200001000, "LOGIN",  '{"user":"alice"}'])

    stmt = conn.prepare("INSERT INTO events(ts, event_type, payload) VALUES(?, ?, ?)")
    for i in range(10):
        stmt.add_batch([1714200002000 + i, "HEARTBEAT", '{"i":%d}' % i])
    stmt.execute_batch()

    # Force the active log segment to roll, then block until the
    # in-process shipper + consolidator have fully applied it to
    # PostgreSQL. Short-lived programs would otherwise exit before
    # the background pipeline gets to drain.
    conn.flush()
    sl.await_sync(DB_PATH, 30.0)
    conn.close()


if __name__ == "__main__":
    main()
