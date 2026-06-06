"""Python mirror of `synclite_rusqlite_store.rs`.

STORE-device sample. The runtime is the system of record, so we open
the connection from a self-contained config file that carries
`device-type=SQLITE_STORE`.
"""

import os
import synclite as sl

DB_PATH = "sample_rusqlite_store_sqlite.db"
DEVICE_NAME = "sampledevice"
CONF_PATH = "sample_rusqlite_store.conf"


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

    sl.initialize(
        device_type="SQLITE_STORE",
        device_name=DEVICE_NAME,
        db_path=DB_PATH,
        config_path=CONF_PATH,
    )

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

    conn.close()


if __name__ == "__main__":
    main()
