// End-to-end SyncLite -> PostgreSQL demo (C++).
//
// Demonstrates `dst_sync_mode = "REPLICATION"`: every row-level operation
// AND every schema-evolution operation executed on the local SQLite
// database is mirrored 1:1 to PostgreSQL by the in-process consolidator.
//
// What the sample exercises:
//   1. users               -- DROP/CREATE TABLE, INSERTs, UPDATE, batch INSERT.
//   2. products            -- ALTER TABLE ADD / RENAME / DROP COLUMN.
//   3. orders -> orders_archive -- ALTER TABLE RENAME TO.
//
// Each step prints a [LOCAL ...] banner; the final block prints a
// short [POSTGRES VERIFY] hint with the queries you can run from
// psql / pgAdmin to confirm the destination state (parity with the
// rust/python/java samples that perform the verify inline; pulling in
// libpq from C++ here would add a non-trivial build dependency).
//
// Safe to re-run repeatedly on the same device: every table is
// DROP'd-IF-EXISTS at the top of its flow so a second run starts
// fresh both locally and on the destination.
//
// Prereqs (one-time, on the PostgreSQL server):
//   CREATE DATABASE syncdb;
//   \c syncdb
//   CREATE SCHEMA syncschema;
//
// Build / run: see ./README.md.

#include "synclite.hpp"

#include <cstdio>
#include <iostream>
#include <string>

namespace sl = synclite;

static const char* DB_PATH     = "sampledevice.db";
static const char* DEVICE_NAME = "sampledevice";
static const char* POSTGRES_SCHEMA = "syncschema";

static void banner(const std::string& text) {
    const std::string bar(62, '=');
    std::cout << "\n" << bar << "\n" << text << "\n" << bar << "\n";
}

static void print_row(const sl::Row& row) {
    std::cout << "    (";
    for (std::size_t i = 0; i < row.size(); ++i) {
        const sl::Value& v = row[i];
        if (i) std::cout << ", ";
        if      (v.is_null()) std::cout << "NULL";
        else if (v.is_int())  std::cout << v.as_int();
        else if (v.is_real()) std::cout << v.as_real();
        else if (v.is_text()) std::cout << "'" << v.as_text() << "'";
        else                  std::cout << "<blob:" << v.as_blob().size() << ">";
    }
    std::cout << ")\n";
}

// ---------------------------------------------------------------------
//  users -- INSERT / UPDATE / batch INSERT
// ---------------------------------------------------------------------
static void run_users_flow(sl::Connection& conn) {
    banner("TABLE users  --  INSERT / UPDATE / batch INSERT");

    std::cout << "[LOCAL DDL] DROP TABLE IF EXISTS users; CREATE TABLE users(id, name, score)\n";
    conn.execute("DROP TABLE IF EXISTS users");
    conn.execute(
        "CREATE TABLE users("
        " id INTEGER PRIMARY KEY, name TEXT, score INTEGER)");

    {
        auto stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)");
        std::cout << "[LOCAL] INSERT users (1, Alice, 100)\n";
        stmt.execute({1, "Alice", 100});
        std::cout << "[LOCAL] INSERT users (2, Bob, 200)\n";
        stmt.execute({2, "Bob",   200});
    }

    std::cout << "[LOCAL] UPDATE users SET score=250 WHERE name='Bob'\n";
    conn.execute("UPDATE users SET score = ? WHERE name = ?", {250, "Bob"});
    conn.commit();

    std::cout << "[LOCAL] INSERT users batch (3, Carol, 300) + (4, Dave, 400)\n";
    {
        auto stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)");
        stmt.add_batch({3, "Carol", 300});
        stmt.add_batch({4, "Dave",  400});
        stmt.execute_batch();
    }
    conn.commit();

    std::cout << "[LOCAL READ] SELECT * FROM users ORDER BY id:\n";
    for (auto& row : conn.query("SELECT id, name, score FROM users ORDER BY id")) {
        print_row(row);
    }
}

// ---------------------------------------------------------------------
//  products -- ALTER TABLE ADD / RENAME / DROP COLUMN
// ---------------------------------------------------------------------
static void run_products_flow(sl::Connection& conn) {
    banner("TABLE products  --  ALTER TABLE ADD / RENAME / DROP COLUMN");

    std::cout << "[LOCAL DDL] DROP TABLE IF EXISTS products; CREATE TABLE products(id, name, price)\n";
    conn.execute("DROP TABLE IF EXISTS products");
    conn.execute(
        "CREATE TABLE products("
        " id INTEGER PRIMARY KEY, name TEXT, price REAL)");

    std::cout << "[LOCAL] INSERT products (1, Widget, 9.99)\n";
    conn.execute("INSERT INTO products(id, name, price) VALUES(?, ?, ?)",
                 {1, "Widget", 9.99});
    conn.commit();

    std::cout << "[LOCAL DDL] ALTER TABLE products ADD COLUMN tag TEXT\n";
    conn.execute("ALTER TABLE products ADD COLUMN tag TEXT");
    std::cout << "[LOCAL] INSERT products using new column (2, Gadget, 19.99, 'new')\n";
    conn.execute("INSERT INTO products(id, name, price, tag) VALUES(?, ?, ?, ?)",
                 {2, "Gadget", 19.99, "new"});
    conn.commit();

    std::cout << "[LOCAL DDL] ALTER TABLE products RENAME COLUMN price TO unit_price\n";
    conn.execute("ALTER TABLE products RENAME COLUMN price TO unit_price");
    std::cout << "[LOCAL] INSERT products using renamed column (3, Sprocket, 29.99, 'gold')\n";
    conn.execute("INSERT INTO products(id, name, unit_price, tag) VALUES(?, ?, ?, ?)",
                 {3, "Sprocket", 29.99, "gold"});
    conn.commit();

    std::cout << "[LOCAL DDL] ALTER TABLE products DROP COLUMN tag\n";
    conn.execute("ALTER TABLE products DROP COLUMN tag");
    conn.commit();

    std::cout << "[LOCAL READ] SELECT * FROM products ORDER BY id (post DROP COLUMN tag):\n";
    for (auto& row : conn.query("SELECT id, name, unit_price FROM products ORDER BY id")) {
        print_row(row);
    }
}

// ---------------------------------------------------------------------
//  orders -> orders_archive -- ALTER TABLE RENAME TO
// ---------------------------------------------------------------------
static void run_orders_flow(sl::Connection& conn) {
    banner("TABLE orders -> orders_archive  --  ALTER TABLE RENAME TO");

    std::cout << "[LOCAL DDL] DROP TABLE IF EXISTS orders_archive; DROP TABLE IF EXISTS orders; CREATE TABLE orders(id, product_id, qty)\n";
    conn.execute("DROP TABLE IF EXISTS orders_archive");
    conn.execute("DROP TABLE IF EXISTS orders");
    conn.execute(
        "CREATE TABLE orders("
        " id INTEGER PRIMARY KEY, product_id INTEGER, qty INTEGER)");

    std::cout << "[LOCAL] INSERT orders (1, 1, 5)\n";
    conn.execute("INSERT INTO orders(id, product_id, qty) VALUES(?, ?, ?)", {1, 1, 5});
    std::cout << "[LOCAL] INSERT orders (2, 2, 3)\n";
    conn.execute("INSERT INTO orders(id, product_id, qty) VALUES(?, ?, ?)", {2, 2, 3});
    conn.commit();

    std::cout << "[LOCAL DDL] ALTER TABLE orders RENAME TO orders_archive\n";
    conn.execute("ALTER TABLE orders RENAME TO orders_archive");

    std::cout << "[LOCAL] INSERT orders_archive (3, 3, 7)  -- written via the new name\n";
    conn.execute("INSERT INTO orders_archive(id, product_id, qty) VALUES(?, ?, ?)", {3, 3, 7});
    conn.commit();

    std::cout << "[LOCAL READ] SELECT * FROM orders_archive ORDER BY id:\n";
    for (auto& row : conn.query("SELECT id, product_id, qty FROM orders_archive ORDER BY id")) {
        print_row(row);
    }
}

// ---------------------------------------------------------------------
//  Verify hint -- run from psql after the sample exits
// ---------------------------------------------------------------------
static void print_verify_hints() {
    banner("VERIFY on PostgreSQL (post await_sync) -- run these from psql");
    std::cout
        << "-- users\n"
        << "SELECT row_to_json(t)::text FROM (SELECT * FROM " << POSTGRES_SCHEMA
        << ".users WHERE id = 4) t;\n\n"
        << "-- products column list (expect: id, name, unit_price)\n"
        << "SELECT column_name, data_type FROM information_schema.columns\n"
        << " WHERE table_schema = '" << POSTGRES_SCHEMA << "' AND table_name = 'products'\n"
        << " ORDER BY ordinal_position;\n\n"
        << "SELECT id, name, unit_price FROM " << POSTGRES_SCHEMA << ".products ORDER BY id;\n\n"
        << "-- rename verification (orders should be gone, orders_archive should exist)\n"
        << "SELECT table_name FROM information_schema.tables\n"
        << " WHERE table_schema = '" << POSTGRES_SCHEMA
        << "' AND table_name IN ('orders','orders_archive');\n"
        << "SELECT id, product_id, qty FROM " << POSTGRES_SCHEMA
        << ".orders_archive ORDER BY id;\n";
}

int main() {
    try {
        // One call wires up the local logger, the segment shipper, and
        // the embedded consolidator that drains into PostgreSQL.
        sl::DestinationOptions dst;
        dst.dst_type              = "POSTGRES";
        dst.dst_connection_string = "postgresql://postgres:postgres@localhost:5432/syncdb";
        dst.dst_database          = "syncdb";
        dst.dst_schema            = POSTGRES_SCHEMA;
        dst.dst_sync_mode         = "REPLICATION";
        sl::initialize("SQLITE", DEVICE_NAME, DB_PATH, dst);

        auto conn = sl::Connection::open(DB_PATH);

        run_users_flow(conn);
        run_products_flow(conn);
        run_orders_flow(conn);

        // Force the active log segment to roll, then block until the
        // in-process shipper + consolidator have fully applied it to
        // PostgreSQL. Short-lived programs would otherwise exit before
        // the background pipeline gets to drain.
        banner("SYNC: flush + await_sync");
        conn.flush();
        try {
            sl::await_sync(DB_PATH, 30.0);
            std::cout << "[SYNC] await_sync succeeded\n";
            print_verify_hints();
        } catch (const std::exception& e) {
            std::cerr << "[SYNC] await_sync failed: " << e.what() << "\n";
            throw;
        }

        conn.close();
        return 0;
    } catch (const std::exception& e) {
        std::fprintf(stderr, "ERROR: %s\n", e.what());
        return 1;
    }
}
