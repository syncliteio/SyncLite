"""Python mirror of `synclite_duckdb_store.rs`.

DUCKDB_STORE device: bulk-friendly variant of the DuckDB sample. Same
DuckDB-backed `DuckDBConnection` API; only `device_type` differs.
"""

import synclite as sl

DB_PATH = "sample_duckdb_store.db"
DEVICE_NAME = "sampledevicestore"


def main() -> None:
    sl.initialize(
        device_type="DUCKDB_STORE",
        device_name=DEVICE_NAME,
        db_path=DB_PATH,
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
    conn.execute("DELETE FROM users WHERE id = ?", [2])

    for row in conn.query("SELECT id, name, score FROM users ORDER BY id"):
        print(row)

    conn.flush()
    sl.await_sync(DB_PATH, 30.0)
    conn.close()


if __name__ == "__main__":
    main()
