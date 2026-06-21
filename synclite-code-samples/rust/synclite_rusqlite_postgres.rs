//! End-to-end SyncLite -> PostgreSQL demo (Rust).
//!
//! Demonstrates `DstSyncMode::Replication`: every row-level operation AND
//! every schema-evolution operation executed on the local SQLite database
//! is mirrored 1:1 to PostgreSQL by the in-process consolidator.
//!
//! What the sample exercises:
//!   1. `users`                          -- DROP/CREATE TABLE, INSERTs,
//!                                          UPDATE, batch INSERT.
//!   2. `products`                       -- ALTER TABLE ADD / RENAME /
//!                                          DROP COLUMN.
//!   3. `orders` -> `orders_archive`     -- ALTER TABLE RENAME TO.
//!
//! Each step prints a `[LOCAL ...]` banner; after `await_sync` the
//! sample reconnects to PostgreSQL with the `postgres` crate and
//! prints `[POSTGRES ...]` lines that show the same data and the
//! same schema on the destination.
//!
//! Safe to re-run repeatedly on the same device: every table is
//! `DROP IF EXISTS`'d at the top of its flow so a second run starts
//! fresh both locally and on the destination.
//!
//! Prereqs (one-time, on the PostgreSQL server):
//!
//! ```sql
//! CREATE DATABASE syncdb;
//! ```
//!
//! The destination schema (`syncschema` by default) is auto-created by
//! the consolidator on startup — no manual `CREATE SCHEMA` step needed.
//!
//! Then run:
//!
//! ```text
//! cargo run --example synclite_rusqlite_postgres
//! ```

use synclite::rusqlite::Connection;
use synclite::{DestinationOptions, DeviceType, DstSyncMode, DstType, Result, SyncLiteOptions, Value};
use postgres::{Client, NoTls};

const DB_PATH: &str = "sampledevice.db";
const DEVICE_NAME: &str = "sampledevice";
const POSTGRES_URL: &str = "postgresql://postgres:postgres@localhost:5432/syncdb";
const POSTGRES_SCHEMA: &str = "syncschema";

fn banner(text: &str) {
    let bar: String = "=".repeat(62);
    println!();
    println!("{bar}");
    println!("{text}");
    println!("{bar}");
}

fn pg_err<E: std::fmt::Display>(e: E) -> synclite::Error {
    synclite::Error::Config(format!("PostgreSQL error: {e}"))
}

// ---------------------------------------------------------------------
//  users -- INSERT / UPDATE / batch INSERT
// ---------------------------------------------------------------------
fn run_users_flow(conn: &mut Connection) -> Result<()> {
    banner("TABLE users  --  INSERT / UPDATE / batch INSERT");

    println!("[LOCAL DDL] DROP TABLE IF EXISTS users; CREATE TABLE users(id, name, score)");
    conn.execute("DROP TABLE IF EXISTS users", &[])?;
    conn.execute(
        "CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)",
        &[],
    )?;

    {
        let mut stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)")?;
        println!("[LOCAL] INSERT users (1, Alice, 100)");
        stmt.execute(&[Value::Int(1), Value::Text("Alice".into()), Value::Int(100)])?;
        println!("[LOCAL] INSERT users (2, Bob, 200)");
        stmt.execute(&[Value::Int(2), Value::Text("Bob".into()), Value::Int(200)])?;
    }

    println!("[LOCAL] UPDATE users SET score=250 WHERE name='Bob'");
    conn.execute(
        "UPDATE users SET score = ? WHERE name = ?",
        &[Value::Int(250), Value::Text("Bob".into())],
    )?;
    conn.commit()?;

    println!("[LOCAL] INSERT users batch (3, Carol, 300) + (4, Dave, 400)");
    {
        let mut stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)")?;
        stmt.add_batch(&[Value::Int(3), Value::Text("Carol".into()), Value::Int(300)]);
        stmt.add_batch(&[Value::Int(4), Value::Text("Dave".into()),  Value::Int(400)]);
        stmt.execute_batch()?;
    }
    conn.commit()?;

    println!("[LOCAL READ] SELECT * FROM users ORDER BY id:");
    for row in conn.query("SELECT id, name, score FROM users ORDER BY id", &[])? {
        println!("    {row:?}");
    }
    Ok(())
}

// ---------------------------------------------------------------------
//  products -- ALTER TABLE ADD / RENAME / DROP COLUMN
// ---------------------------------------------------------------------
fn run_products_flow(conn: &mut Connection) -> Result<()> {
    banner("TABLE products  --  ALTER TABLE ADD / RENAME / DROP COLUMN");

    println!("[LOCAL DDL] DROP TABLE IF EXISTS products; CREATE TABLE products(id, name, price)");
    conn.execute("DROP TABLE IF EXISTS products", &[])?;
    conn.execute(
        "CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT, price REAL)",
        &[],
    )?;

    println!("[LOCAL] INSERT products (1, Widget, 9.99)");
    conn.execute(
        "INSERT INTO products(id, name, price) VALUES(?, ?, ?)",
        &[Value::Int(1), Value::Text("Widget".into()), Value::Real(9.99)],
    )?;
    conn.commit()?;

    println!("[LOCAL DDL] ALTER TABLE products ADD COLUMN tag TEXT");
    conn.execute("ALTER TABLE products ADD COLUMN tag TEXT", &[])?;
    println!("[LOCAL] INSERT products using new column (2, Gadget, 19.99, 'new')");
    conn.execute(
        "INSERT INTO products(id, name, price, tag) VALUES(?, ?, ?, ?)",
        &[
            Value::Int(2),
            Value::Text("Gadget".into()),
            Value::Real(19.99),
            Value::Text("new".into()),
        ],
    )?;
    conn.commit()?;

    println!("[LOCAL DDL] ALTER TABLE products RENAME COLUMN price TO unit_price");
    conn.execute("ALTER TABLE products RENAME COLUMN price TO unit_price", &[])?;
    println!("[LOCAL] INSERT products using renamed column (3, Sprocket, 29.99, 'gold')");
    conn.execute(
        "INSERT INTO products(id, name, unit_price, tag) VALUES(?, ?, ?, ?)",
        &[
            Value::Int(3),
            Value::Text("Sprocket".into()),
            Value::Real(29.99),
            Value::Text("gold".into()),
        ],
    )?;
    conn.commit()?;

    println!("[LOCAL DDL] ALTER TABLE products DROP COLUMN tag");
    conn.execute("ALTER TABLE products DROP COLUMN tag", &[])?;
    conn.commit()?;

    println!("[LOCAL READ] SELECT * FROM products ORDER BY id (post DROP COLUMN tag):");
    for row in conn.query("SELECT id, name, unit_price FROM products ORDER BY id", &[])? {
        println!("    {row:?}");
    }
    Ok(())
}

// ---------------------------------------------------------------------
//  orders -> orders_archive -- ALTER TABLE RENAME TO
// ---------------------------------------------------------------------
fn run_orders_flow(conn: &mut Connection) -> Result<()> {
    banner("TABLE orders -> orders_archive  --  ALTER TABLE RENAME TO");

    println!("[LOCAL DDL] DROP TABLE IF EXISTS orders_archive; DROP TABLE IF EXISTS orders; CREATE TABLE orders(id, product_id, qty)");
    conn.execute("DROP TABLE IF EXISTS orders_archive", &[])?;
    conn.execute("DROP TABLE IF EXISTS orders", &[])?;
    conn.execute(
        "CREATE TABLE orders(id INTEGER PRIMARY KEY, product_id INTEGER, qty INTEGER)",
        &[],
    )?;

    println!("[LOCAL] INSERT orders (1, 1, 5)");
    conn.execute(
        "INSERT INTO orders(id, product_id, qty) VALUES(?, ?, ?)",
        &[Value::Int(1), Value::Int(1), Value::Int(5)],
    )?;
    println!("[LOCAL] INSERT orders (2, 2, 3)");
    conn.execute(
        "INSERT INTO orders(id, product_id, qty) VALUES(?, ?, ?)",
        &[Value::Int(2), Value::Int(2), Value::Int(3)],
    )?;
    conn.commit()?;

    println!("[LOCAL DDL] ALTER TABLE orders RENAME TO orders_archive");
    conn.execute("ALTER TABLE orders RENAME TO orders_archive", &[])?;

    println!("[LOCAL] INSERT orders_archive (3, 3, 7)  -- written via the new name");
    conn.execute(
        "INSERT INTO orders_archive(id, product_id, qty) VALUES(?, ?, ?)",
        &[Value::Int(3), Value::Int(3), Value::Int(7)],
    )?;
    conn.commit()?;

    println!("[LOCAL READ] SELECT * FROM orders_archive ORDER BY id:");
    for row in conn.query("SELECT id, product_id, qty FROM orders_archive ORDER BY id", &[])? {
        println!("    {row:?}");
    }
    Ok(())
}

// ---------------------------------------------------------------------
//  Verify on PostgreSQL after await_sync
// ---------------------------------------------------------------------
fn verify_on_postgres() -> Result<()> {
    banner("VERIFY on PostgreSQL (post await_sync)");

    let mut pg = Client::connect(POSTGRES_URL, NoTls).map_err(pg_err)?;

    let row = pg
        .query_opt(
            &format!(
                "SELECT row_to_json(t)::text FROM (SELECT * FROM {POSTGRES_SCHEMA}.users WHERE id = $1) t"
            ),
            &[&4_i64],
        )
        .map_err(pg_err)?;
    println!(
        "[POSTGRES] {POSTGRES_SCHEMA}.users WHERE id=4 -> {}",
        row.as_ref().map(|r| r.get::<usize, String>(0)).unwrap_or_else(|| "(no row)".into())
    );

    println!(
        "[POSTGRES] {POSTGRES_SCHEMA}.products column list \
         (expect: id, name, unit_price; 'tag' dropped, 'price' renamed):"
    );
    for r in pg
        .query(
            "SELECT column_name, data_type FROM information_schema.columns \
             WHERE table_schema = $1 AND table_name = 'products' ORDER BY ordinal_position",
            &[&POSTGRES_SCHEMA],
        )
        .map_err(pg_err)?
    {
        println!("    {}  ({})", r.get::<usize, String>(0), r.get::<usize, String>(1));
    }

    println!("[POSTGRES] {POSTGRES_SCHEMA}.products rows:");
    for r in pg
        .query(
            &format!("SELECT id, name, unit_price FROM {POSTGRES_SCHEMA}.products ORDER BY id"),
            &[],
        )
        .map_err(pg_err)?
    {
        println!(
            "    id={}, name={}, unit_price={}",
            r.get::<usize, i64>(0),
            r.get::<usize, String>(1),
            r.get::<usize, f64>(2)
        );
    }

    let orders_exists = pg
        .query_opt(
            "SELECT 1 FROM information_schema.tables WHERE table_schema = $1 AND table_name = $2",
            &[&POSTGRES_SCHEMA, &"orders"],
        )
        .map_err(pg_err)?
        .is_some();
    let archive_exists = pg
        .query_opt(
            "SELECT 1 FROM information_schema.tables WHERE table_schema = $1 AND table_name = $2",
            &[&POSTGRES_SCHEMA, &"orders_archive"],
        )
        .map_err(pg_err)?
        .is_some();
    println!("[POSTGRES] {POSTGRES_SCHEMA}.orders exists         -> {orders_exists}  (expect false  -- renamed away)");
    println!("[POSTGRES] {POSTGRES_SCHEMA}.orders_archive exists -> {archive_exists}  (expect true)");
    if archive_exists {
        println!("[POSTGRES] {POSTGRES_SCHEMA}.orders_archive rows:");
        for r in pg
            .query(
                &format!("SELECT id, product_id, qty FROM {POSTGRES_SCHEMA}.orders_archive ORDER BY id"),
                &[],
            )
            .map_err(pg_err)?
        {
            println!(
                "    id={}, product_id={}, qty={}",
                r.get::<usize, i64>(0),
                r.get::<usize, i64>(1),
                r.get::<usize, i64>(2)
            );
        }
    }
    Ok(())
}

fn main() -> Result<()> {
    // One call wires up the local logger, the segment shipper, and the
    // embedded consolidator that drains into PostgreSQL.
    synclite::initialize(
        DeviceType::SQLITE,
        DEVICE_NAME,
        DB_PATH,
        Some(DestinationOptions {
            dst_type: DstType::Postgres,
            dst_connection_string: POSTGRES_URL.into(),
            dst_database: Some("syncdb".into()),
            dst_schema: Some(POSTGRES_SCHEMA.into()),
            dst_sync_mode: DstSyncMode::Replication,
        }),
        SyncLiteOptions::default(),
    )?;

    let mut conn = Connection::open(DB_PATH)?;

    run_users_flow(&mut conn)?;
    run_products_flow(&mut conn)?;
    run_orders_flow(&mut conn)?;

    // Force the active log segment to roll, then block until the
    // in-process shipper + consolidator have fully applied it to
    // PostgreSQL. Short-lived programs would otherwise exit before the
    // background pipeline gets to drain.
    banner("SYNC: flush + await_sync");
    conn.flush()?;
    match synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30)) {
        Ok(()) => {
            println!("[SYNC] await_sync succeeded");
            if let Err(e) = verify_on_postgres() {
                println!("[POSTGRES] verify skipped: {e}");
            }
        }
        Err(e) => {
            println!("[SYNC] await_sync failed: {e}");
            conn.close()?;
            return Err(e);
        }
    }

    conn.close()?;
    Ok(())
}
