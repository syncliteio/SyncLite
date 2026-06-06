"""Python mirror of `synclite_streaming.rs`.

STREAMING-device sample. Same `Connection` API as the txn / store
samples; only `device-type` differs (configured in the conf file).
"""

import synclite as sl

DB_PATH = "sample_streaming_sqlite.db"
DEVICE_NAME = "sampledevice"
CONF_PATH = "sample_streaming.conf"


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

    sl.initialize(
        device_type="STREAMING",
        device_name=DEVICE_NAME,
        db_path=DB_PATH,
        config_path=CONF_PATH,
    )

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

    conn.close()


if __name__ == "__main__":
    main()
