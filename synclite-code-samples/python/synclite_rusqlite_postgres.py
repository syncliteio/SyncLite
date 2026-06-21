"""End-to-end SyncLite -> PostgreSQL demo (Python).

Drives the SyncLite Rust runtime via the `synclite` Python package -
no JVM, no JAR. Demonstrates `dst_sync_mode="REPLICATION"`: every
row-level operation AND every schema-evolution operation executed on
the local SQLite database is mirrored 1:1 to PostgreSQL by the
in-process consolidator.

What the sample exercises:
  1. users               -- DROP / CREATE TABLE, INSERTs, UPDATE, batch INSERT.
  2. products            -- ALTER TABLE ADD / RENAME / DROP COLUMN.
  3. orders -> orders_archive -- ALTER TABLE RENAME TO.

Each step prints a [LOCAL ...] banner; after await_sync the script
reconnects to PostgreSQL with psycopg and prints [POSTGRES ...]
lines that show the same data and schema on the destination.

Safe to re-run repeatedly on the same device: every table is
DROP'd-IF-EXISTS at the top of its flow so a second run starts
fresh both locally and on the destination.

Prereqs (one-time, on the PostgreSQL server):

    CREATE DATABASE syncdb;

The consolidator auto-creates the schema (`CREATE SCHEMA IF NOT EXISTS`)
on first run, so pre-creating the database is enough.

Edit POSTGRES_CONN below to match your credentials, then:

    pip install "psycopg[binary]"
    python synclite_rusqlite_postgres.py

See ../README.md for the synclite package install / setup.
"""

import synclite as sl

DB_PATH = "sampledevice.db"
DEVICE_NAME = "sampledevice"
POSTGRES_CONN = "postgresql://postgres:postgres@localhost:5432/syncdb"
POSTGRES_SCHEMA = "syncschema"


def banner(text: str) -> None:
    bar = "=" * 62
    print()
    print(bar)
    print(text)
    print(bar)


# ---------------------------------------------------------------------
#  users -- INSERT / UPDATE / batch INSERT
# ---------------------------------------------------------------------
def run_users_flow(conn) -> None:
    banner("TABLE users  --  INSERT / UPDATE / batch INSERT")

    print("[LOCAL DDL] DROP TABLE IF EXISTS users; CREATE TABLE users(id, name, score)")
    conn.execute("DROP TABLE IF EXISTS users")
    conn.execute(
        "CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)"
    )

    stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)")
    print("[LOCAL] INSERT users (1, Alice, 100)")
    stmt.execute([1, "Alice", 100])
    print("[LOCAL] INSERT users (2, Bob, 200)")
    stmt.execute([2, "Bob", 200])

    print("[LOCAL] UPDATE users SET score=250 WHERE name='Bob'")
    conn.execute("UPDATE users SET score = ? WHERE name = ?", [250, "Bob"])
    conn.commit()

    print("[LOCAL] INSERT users batch (3, Carol, 300) + (4, Dave, 400)")
    stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)")
    stmt.add_batch([3, "Carol", 300])
    stmt.add_batch([4, "Dave",  400])
    stmt.execute_batch()
    conn.commit()

    print("[LOCAL READ] SELECT * FROM users ORDER BY id:")
    for row in conn.query("SELECT id, name, score FROM users ORDER BY id"):
        print(f"    {row}")


# ---------------------------------------------------------------------
#  products -- ALTER TABLE ADD / RENAME / DROP COLUMN
# ---------------------------------------------------------------------
def run_products_flow(conn) -> None:
    banner("TABLE products  --  ALTER TABLE ADD / RENAME / DROP COLUMN")

    print("[LOCAL DDL] DROP TABLE IF EXISTS products; CREATE TABLE products(id, name, price)")
    conn.execute("DROP TABLE IF EXISTS products")
    conn.execute(
        "CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT, price REAL)"
    )

    print("[LOCAL] INSERT products (1, Widget, 9.99)")
    conn.execute(
        "INSERT INTO products(id, name, price) VALUES(?, ?, ?)",
        [1, "Widget", 9.99],
    )
    conn.commit()

    print("[LOCAL DDL] ALTER TABLE products ADD COLUMN tag TEXT")
    conn.execute("ALTER TABLE products ADD COLUMN tag TEXT")
    print("[LOCAL] INSERT products using new column (2, Gadget, 19.99, 'new')")
    conn.execute(
        "INSERT INTO products(id, name, price, tag) VALUES(?, ?, ?, ?)",
        [2, "Gadget", 19.99, "new"],
    )
    conn.commit()

    print("[LOCAL DDL] ALTER TABLE products RENAME COLUMN price TO unit_price")
    conn.execute("ALTER TABLE products RENAME COLUMN price TO unit_price")
    print("[LOCAL] INSERT products using renamed column (3, Sprocket, 29.99, 'gold')")
    conn.execute(
        "INSERT INTO products(id, name, unit_price, tag) VALUES(?, ?, ?, ?)",
        [3, "Sprocket", 29.99, "gold"],
    )
    conn.commit()

    print("[LOCAL DDL] ALTER TABLE products DROP COLUMN tag")
    conn.execute("ALTER TABLE products DROP COLUMN tag")
    conn.commit()

    print("[LOCAL READ] SELECT * FROM products ORDER BY id (post DROP COLUMN tag):")
    for row in conn.query("SELECT id, name, unit_price FROM products ORDER BY id"):
        print(f"    {row}")


# ---------------------------------------------------------------------
#  orders -> orders_archive -- ALTER TABLE RENAME TO
# ---------------------------------------------------------------------
def run_orders_flow(conn) -> None:
    banner("TABLE orders -> orders_archive  --  ALTER TABLE RENAME TO")

    print("[LOCAL DDL] DROP TABLE IF EXISTS orders_archive; DROP TABLE IF EXISTS orders; CREATE TABLE orders(id, product_id, qty)")
    conn.execute("DROP TABLE IF EXISTS orders_archive")
    conn.execute("DROP TABLE IF EXISTS orders")
    conn.execute(
        "CREATE TABLE orders(id INTEGER PRIMARY KEY, product_id INTEGER, qty INTEGER)"
    )

    print("[LOCAL] INSERT orders (1, 1, 5)")
    conn.execute("INSERT INTO orders(id, product_id, qty) VALUES(?, ?, ?)", [1, 1, 5])
    print("[LOCAL] INSERT orders (2, 2, 3)")
    conn.execute("INSERT INTO orders(id, product_id, qty) VALUES(?, ?, ?)", [2, 2, 3])
    conn.commit()

    print("[LOCAL DDL] ALTER TABLE orders RENAME TO orders_archive")
    conn.execute("ALTER TABLE orders RENAME TO orders_archive")

    print("[LOCAL] INSERT orders_archive (3, 3, 7)  -- written via the new name")
    conn.execute(
        "INSERT INTO orders_archive(id, product_id, qty) VALUES(?, ?, ?)",
        [3, 3, 7],
    )
    conn.commit()

    print("[LOCAL READ] SELECT * FROM orders_archive ORDER BY id:")
    for row in conn.query("SELECT id, product_id, qty FROM orders_archive ORDER BY id"):
        print(f"    {row}")


# ---------------------------------------------------------------------
#  Verify on PostgreSQL after await_sync
# ---------------------------------------------------------------------
def verify_on_postgres() -> None:
    banner("VERIFY on PostgreSQL (post await_sync)")

    try:
        import psycopg
    except ImportError:
        print("[POSTGRES] psycopg not installed (`pip install psycopg`); skipping verify.")
        return

    with psycopg.connect(POSTGRES_CONN) as pg:
        with pg.cursor() as cur:
            cur.execute(
                f"SELECT row_to_json(t)::text FROM (SELECT * FROM {POSTGRES_SCHEMA}.users WHERE id = %s) t",
                (4,),
            )
            row = cur.fetchone()
            print(f"[POSTGRES] {POSTGRES_SCHEMA}.users WHERE id=4 -> {row[0] if row else '(no row)'}")

            print(
                f"[POSTGRES] {POSTGRES_SCHEMA}.products column list "
                "(expect: id, name, unit_price; 'tag' dropped, 'price' renamed):"
            )
            cur.execute(
                "SELECT column_name, data_type FROM information_schema.columns "
                "WHERE table_schema = %s AND table_name = 'products' ORDER BY ordinal_position",
                (POSTGRES_SCHEMA,),
            )
            for col, dtype in cur.fetchall():
                print(f"    {col}  ({dtype})")

            print(f"[POSTGRES] {POSTGRES_SCHEMA}.products rows:")
            cur.execute(
                f"SELECT id, name, unit_price FROM {POSTGRES_SCHEMA}.products ORDER BY id"
            )
            for r in cur.fetchall():
                print(f"    id={r[0]}, name={r[1]}, unit_price={r[2]}")

            cur.execute(
                "SELECT 1 FROM information_schema.tables "
                "WHERE table_schema = %s AND table_name = %s",
                (POSTGRES_SCHEMA, "orders"),
            )
            orders_exists = cur.fetchone() is not None
            cur.execute(
                "SELECT 1 FROM information_schema.tables "
                "WHERE table_schema = %s AND table_name = %s",
                (POSTGRES_SCHEMA, "orders_archive"),
            )
            archive_exists = cur.fetchone() is not None
            print(f"[POSTGRES] {POSTGRES_SCHEMA}.orders exists         -> {orders_exists}  (expect False  -- renamed away)")
            print(f"[POSTGRES] {POSTGRES_SCHEMA}.orders_archive exists -> {archive_exists}  (expect True)")
            if archive_exists:
                print(f"[POSTGRES] {POSTGRES_SCHEMA}.orders_archive rows:")
                cur.execute(
                    f"SELECT id, product_id, qty FROM {POSTGRES_SCHEMA}.orders_archive ORDER BY id"
                )
                for r in cur.fetchall():
                    print(f"    id={r[0]}, product_id={r[1]}, qty={r[2]}")


def main() -> None:
    # One call wires up the local logger, the segment shipper, and the
    # embedded consolidator that drains into PostgreSQL.
    sl.initialize(
        device_type="SQLITE",
        device_name=DEVICE_NAME,
        db_path=DB_PATH,
        destination=sl.DestinationOptions(
            dst_type="POSTGRES",
            dst_connection_string=POSTGRES_CONN,
            dst_database="syncdb",
            dst_schema=POSTGRES_SCHEMA,
            dst_sync_mode="REPLICATION",
        ),
    )

    conn = sl.Connection.open(DB_PATH)
    try:
        run_users_flow(conn)
        run_products_flow(conn)
        run_orders_flow(conn)
    finally:
        # Force the active log segment to roll, then block until the
        # in-process shipper + consolidator have fully applied it to
        # PostgreSQL. Short-lived programs would otherwise exit before
        # the background pipeline gets to drain.
        conn.flush()
        try:
            sl.await_sync(DB_PATH, 30.0)
            print("\n[SYNC] await_sync succeeded")
            verify_on_postgres()
        except Exception as exc:
            print(f"\n[SYNC] await_sync failed: {exc}")
        finally:
            conn.close()


if __name__ == "__main__":
    main()
