"""SyncLite SQLAlchemy sample using the sqlite+synclite dialect."""

import synclite as sl
from synclite import dbapi2
from sqlalchemy import create_engine, text

DB_PATH = "sample_sqlalchemy.db"
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
    engine = create_engine(f"sqlite+synclite:///{DB_PATH}")
    try:
        with engine.begin() as connection:
            connection.execute(text("DROP TABLE IF EXISTS users"))
            connection.execute(text("CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)"))
            connection.execute(
                text("INSERT INTO users(id, name, score) VALUES(:id, :name, :score)"),
                [{"id": 1, "name": "Alice", "score": 100},
                 {"id": 2, "name": "Bob", "score": 200},
                 {"id": 3, "name": "Carol", "score": 300}],
            )
            connection.execute(
                text("UPDATE users SET score = :score WHERE id = :id"),
                {"score": 250, "id": 2},
            )
            print("[LOCAL]", connection.execute(text("SELECT * FROM users ORDER BY id")).all())
    finally:
        engine.dispose()
    # Roll committed log work before awaiting PostgreSQL in a short-lived demo.
    sync_conn = dbapi2.connect(DB_PATH)
    try:
        sync_conn.flush()
        sl.await_sync(DB_PATH, 30.0)
        print("[SYNC] await_sync succeeded")
    finally:
        sync_conn.close()


if __name__ == "__main__":
    main()
