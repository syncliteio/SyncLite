import os
import sqlite3


def main() -> None:
    db_path = os.path.join(
        os.environ.get("USERPROFILE", ""),
        "synclite",
        "test",
        "workDir",
        "consolidated_db.sqlite",
    )
    if not os.path.exists(db_path):
        print("dest_db_missing")
        return

    conn = sqlite3.connect(db_path)
    try:
        rows = [
            r[0]
            for r in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
            )
        ]
    finally:
        conn.close()

    print(f"table_count {len(rows)}")
    for name in rows:
        print(name)


if __name__ == "__main__":
    main()
