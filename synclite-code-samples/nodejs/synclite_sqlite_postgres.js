/**
 * End-to-end SyncLite -> PostgreSQL demo (Node.js).
 *
 * Drives the SyncLite Rust runtime via the `synclite` Node.js N-API binding -
 * no JVM, no JAR. Demonstrates `dst_sync_mode="REPLICATION"`: every
 * row-level operation AND every schema-evolution operation executed on
 * the local SQLite database is mirrored 1:1 to PostgreSQL by the
 * in-process consolidator.
 *
 * What the sample exercises:
 *   1. users               -- DROP / CREATE TABLE, INSERTs, UPDATE, batch INSERT.
 *   2. products            -- ALTER TABLE ADD / RENAME / DROP COLUMN.
 *   3. orders -> orders_archive -- ALTER TABLE RENAME TO.
 *
 * Each step prints a [LOCAL ...] banner; after awaitSync the script
 * reconnects to PostgreSQL with pg and prints [POSTGRES ...]
 * lines that show the same data and schema on the destination.
 *
 * Safe to re-run repeatedly on the same device: every table is
 * DROP'd-IF-EXISTS at the top of its flow so a second run starts
 * fresh both locally and on the destination.
 *
 * Prereqs (one-time, on the PostgreSQL server):
 *
 *     CREATE DATABASE syncdb;
 *
 * The consolidator auto-creates the schema (`CREATE SCHEMA IF NOT EXISTS`)
 * on first run, so pre-creating the database is enough.
 *
 * Edit POSTGRES_URL below to match your credentials, then:
 *
 *     npm install synclite pg
 *     node synclite_sqlite_postgres.js
 *
 * See README.md for the synclite package install / setup.
 */

const { Client } = require('pg');
const { initialize, SqliteConnection, awaitSync } = require('synclite');

const DB_PATH = 'sampledevice.db';
const DEVICE_NAME = 'sampledevice';
const POSTGRES_URL = 'postgresql://postgres:postgres@localhost:5432/syncdb';
const POSTGRES_SCHEMA = 'syncschema';

function banner(message) {
  console.log(`\n${'='.repeat(62)}\n${message}\n${'='.repeat(62)}`);
}

function usersFlow(conn) {
  banner('TABLE users  --  INSERT / UPDATE / batch INSERT');

  console.log("[LOCAL DDL] DROP TABLE IF EXISTS users; CREATE TABLE users(id, name, score)");
  conn.execute('DROP TABLE IF EXISTS users');
  conn.execute('CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)');

  const stmt = conn.prepare('INSERT INTO users(id, name, score) VALUES(?, ?, ?)');
  console.log("[LOCAL] INSERT users (1, Alice, 100)");
  stmt.execute([1, 'Alice', 100]);
  console.log("[LOCAL] INSERT users (2, Bob, 200)");
  stmt.execute([2, 'Bob', 200]);

  console.log("[LOCAL] UPDATE users SET score=250 WHERE name='Bob'");
  conn.execute('UPDATE users SET score = ? WHERE name = ?', [250, 'Bob']);
  conn.commit();

  console.log("[LOCAL] INSERT users batch (3, Carol, 300) + (4, Dave, 400)");
  const stmt2 = conn.prepare('INSERT INTO users(id, name, score) VALUES(?, ?, ?)');
  stmt2.addBatch([3, 'Carol', 300]);
  stmt2.addBatch([4, 'Dave', 400]);
  stmt2.executeBatch();
  conn.commit();

  console.log("[LOCAL READ] SELECT * FROM users ORDER BY id:");
  const rows = conn.query('SELECT id, name, score FROM users ORDER BY id');
  for (const row of rows) {
    console.log(`    ${JSON.stringify(row)}`);
  }
}

function productsFlow(conn) {
  banner('TABLE products  --  ALTER TABLE ADD / RENAME / DROP COLUMN');

  console.log("[LOCAL DDL] DROP TABLE IF EXISTS products; CREATE TABLE products(id, name, price)");
  conn.execute('DROP TABLE IF EXISTS products');
  conn.execute('CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT, price REAL)');

  console.log("[LOCAL] INSERT products (1, Widget, 9.99)");
  conn.execute('INSERT INTO products(id, name, price) VALUES(?, ?, ?)', [1, 'Widget', 9.99]);
  conn.commit();

  console.log("[LOCAL DDL] ALTER TABLE products ADD COLUMN tag TEXT");
  conn.execute('ALTER TABLE products ADD COLUMN tag TEXT');
  console.log("[LOCAL] INSERT products using new column (2, Gadget, 19.99, 'new')");
  conn.execute('INSERT INTO products(id, name, price, tag) VALUES(?, ?, ?, ?)', [2, 'Gadget', 19.99, 'new']);
  conn.commit();

  console.log("[LOCAL DDL] ALTER TABLE products RENAME COLUMN price TO unit_price");
  conn.execute('ALTER TABLE products RENAME COLUMN price TO unit_price');
  console.log("[LOCAL] INSERT products using renamed column (3, Sprocket, 29.99, 'gold')");
  conn.execute('INSERT INTO products(id, name, unit_price, tag) VALUES(?, ?, ?, ?)', [3, 'Sprocket', 29.99, 'gold']);
  conn.commit();

  console.log("[LOCAL DDL] ALTER TABLE products DROP COLUMN tag");
  conn.execute('ALTER TABLE products DROP COLUMN tag');
  conn.commit();

  console.log("[LOCAL READ] SELECT * FROM products ORDER BY id (post DROP COLUMN tag):");
  const rows = conn.query('SELECT id, name, unit_price FROM products ORDER BY id');
  for (const row of rows) {
    console.log(`    ${JSON.stringify(row)}`);
  }
}

function ordersFlow(conn) {
  banner('TABLE orders -> orders_archive  --  ALTER TABLE RENAME TO');

  console.log("[LOCAL DDL] DROP TABLE IF EXISTS orders_archive; DROP TABLE IF EXISTS orders; CREATE TABLE orders(id, product_id, qty)");
  conn.execute('DROP TABLE IF EXISTS orders_archive');
  conn.execute('DROP TABLE IF EXISTS orders');
  conn.execute('CREATE TABLE orders(id INTEGER PRIMARY KEY, product_id INTEGER, qty INTEGER)');

  console.log("[LOCAL] INSERT orders (1, 1, 5)");
  conn.execute('INSERT INTO orders(id, product_id, qty) VALUES(?, ?, ?)', [1, 1, 5]);
  console.log("[LOCAL] INSERT orders (2, 2, 3)");
  conn.execute('INSERT INTO orders(id, product_id, qty) VALUES(?, ?, ?)', [2, 2, 3]);
  conn.commit();

  console.log("[LOCAL DDL] ALTER TABLE orders RENAME TO orders_archive");
  conn.execute('ALTER TABLE orders RENAME TO orders_archive');
  conn.commit();

  console.log("[LOCAL] INSERT orders_archive (3, 3, 7)  -- written via the new name");
  conn.execute(
    'INSERT INTO orders_archive(id, product_id, qty) VALUES(?, ?, ?)',
    [3, 3, 7],
  );
  conn.commit();

  console.log("[LOCAL READ] SELECT * FROM orders_archive ORDER BY id:");
  const rows = conn.query('SELECT id, product_id, qty FROM orders_archive ORDER BY id');
  for (const row of rows) {
    console.log(`    ${JSON.stringify(row)}`);
  }
}

async function verifyPostgres() {
  banner('VERIFY on PostgreSQL (post awaitSync)');
  const client = new Client({ connectionString: POSTGRES_URL });
  
  try {
    await client.connect();
    
    const users = await client.query(`SELECT row_to_json(t)::text FROM (SELECT * FROM ${POSTGRES_SCHEMA}.users WHERE id = $1) t`, [4]);
    const row = users.rows[0];
    console.log(`[POSTGRES] ${POSTGRES_SCHEMA}.users WHERE id=4 -> ${row ? row.row_to_json : '(no row)'}`);
    
    console.log(`[POSTGRES] ${POSTGRES_SCHEMA}.products column list (expect: id, name, unit_price; 'tag' dropped, 'price' renamed):`);
    const cols = await client.query(
      'SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = $1 AND table_name = \'products\' ORDER BY ordinal_position',
      [POSTGRES_SCHEMA]
    );
    for (const col of cols.rows) {
      console.log(`    ${col.column_name}  (${col.data_type})`);
    }
    
    console.log(`[POSTGRES] ${POSTGRES_SCHEMA}.products rows:`);
    const products = await client.query(`SELECT id, name, unit_price FROM ${POSTGRES_SCHEMA}.products ORDER BY id`);
    for (const row of products.rows) {
      console.log(`    id=${row.id}, name=${row.name}, unit_price=${row.unit_price}`);
    }
    
    const ordersExists = await client.query(
      'SELECT 1 FROM information_schema.tables WHERE table_schema = $1 AND table_name = \'orders\'',
      [POSTGRES_SCHEMA]
    );
    const archiveExists = await client.query(
      'SELECT 1 FROM information_schema.tables WHERE table_schema = $1 AND table_name = \'orders_archive\'',
      [POSTGRES_SCHEMA]
    );
    console.log(`[POSTGRES] ${POSTGRES_SCHEMA}.orders exists         -> ${ordersExists.rows.length > 0}  (expect false  -- renamed away)`);
    console.log(`[POSTGRES] ${POSTGRES_SCHEMA}.orders_archive exists -> ${archiveExists.rows.length > 0}  (expect true)`);
    
    if (archiveExists.rows.length > 0) {
      console.log(`[POSTGRES] ${POSTGRES_SCHEMA}.orders_archive rows:`);
      const archive = await client.query(`SELECT id, product_id, qty FROM ${POSTGRES_SCHEMA}.orders_archive ORDER BY id`);
      for (const row of archive.rows) {
        console.log(`    id=${row.id}, product_id=${row.product_id}, qty=${row.qty}`);
      }
    }
  } catch (error) {
    console.error('[POSTGRES connection or query failed]', error.message);
  } finally {
    await client.end();
  }
}

async function main() {
  // One call wires up the local logger, the segment shipper, and the
  // embedded consolidator that drains into PostgreSQL.
  initialize({
    device_type: 'SQLITE',
    device_name: DEVICE_NAME,
    db_path: DB_PATH,
    destination: {
      dst_type: 'POSTGRES',
      dst_connection_string: POSTGRES_URL,
      dst_database: 'syncdb',
      dst_schema: POSTGRES_SCHEMA,
      dst_sync_mode: 'REPLICATION',
    },
  });

  const conn = SqliteConnection.open(DB_PATH);
  try {
    usersFlow(conn);
    productsFlow(conn);
    ordersFlow(conn);
    conn.flush();
    awaitSync(DB_PATH, 30);
    await verifyPostgres();
  } finally {
    conn.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
