/*
 * Copyright (c) 2025 mahendra.chavan@synclite.io, all rights reserved.
 *
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied.  See the License for the specific language governing permissions and limitations
 * under the License.
 *
 */
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Duration;

import io.synclite.DestinationOptions;
import io.synclite.DstSyncMode;
import io.synclite.DstType;
import io.synclite.SQLite;
import io.synclite.SyncLite;

/**
 * Offline-first SQLite app that syncs every change to PostgreSQL.
 */
public class SyncliteSqlitePostgresApp {
    private static final Path DB_PATH = Path.of("sampledevice.db");
    private static final String DEVICE_NAME = "sampledevice";
    private static final String POSTGRES_URL =
            "jdbc:postgresql://localhost:5432/syncdb?user=postgres&password=postgres";
    private static final String POSTGRES_USER = "postgres";
    private static final String POSTGRES_PASSWORD = "postgres";
    private static final String POSTGRES_DB = "syncdb";
    private static final String POSTGRES_SCHEMA = "syncschema";
    private static final Duration AWAIT_TIMEOUT = Duration.ofSeconds(30);

    public static void main(String[] args) throws SQLException {
        appStartup();
        try {
            new SyncliteSqlitePostgresApp().runBusinessLogic();
        } finally {
            SQLite.closeDevice(DB_PATH);
        }
    }

    public static void appStartup() throws SQLException {
        DestinationOptions destination = DestinationOptions.builder()
                .dstType(DstType.POSTGRES)
                .connectionString(POSTGRES_URL)
                .database(POSTGRES_DB)
                .schema(POSTGRES_SCHEMA)
                .syncMode(DstSyncMode.REPLICATION)
                .build();
        SQLite.initialize(DB_PATH, DEVICE_NAME, destination);
    }

    public void runBusinessLogic() throws SQLException {
        try (Connection conn = DriverManager.getConnection(
                "jdbc:synclite_sqlite:" + DB_PATH)) {
            runUsersFlow(conn);
            runProductsFlow(conn);
            runOrdersFlow(conn);
            banner("SYNC: flush + awaitSync");
            try {
                SyncLite.awaitSync(DB_PATH, AWAIT_TIMEOUT);
                System.out.println("[SYNC] awaitSync succeeded");
            } catch (SQLException e) {
                System.out.println("[SYNC] awaitSync failed: " + e.getMessage());
                throw e;
            }
        }
        verifyOnPostgres();
    }

    private void runUsersFlow(Connection conn) throws SQLException {
        banner("TABLE users  --  INSERT / UPDATE / batch INSERT");
        try (Statement stmt = conn.createStatement()) {
            System.out.println("[LOCAL DDL] DROP TABLE IF EXISTS users; CREATE TABLE users(id, name, score)");
            stmt.execute("DROP TABLE IF EXISTS users");
            stmt.execute("CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)");
        }
        try (PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO users(id, name, score) VALUES(?, ?, ?)")) {
            System.out.println("[LOCAL] INSERT users (1, Alice, 100)");
            pstmt.setInt(1, 1); pstmt.setString(2, "Alice"); pstmt.setInt(3, 100);
            pstmt.executeUpdate();
            System.out.println("[LOCAL] INSERT users (2, Bob, 200)");
            pstmt.setInt(1, 2); pstmt.setString(2, "Bob"); pstmt.setInt(3, 200);
            pstmt.executeUpdate();
        }
        try (PreparedStatement pstmt = conn.prepareStatement(
                "UPDATE users SET score = ? WHERE name = ?")) {
            System.out.println("[LOCAL] UPDATE users SET score=250 WHERE name='Bob'");
            pstmt.setInt(1, 250); pstmt.setString(2, "Bob");
            pstmt.executeUpdate();
        }
        conn.commit();
        try (PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO users(id, name, score) VALUES(?, ?, ?)")) {
            System.out.println("[LOCAL] INSERT users batch (3, Carol, 300) + (4, Dave, 400)");
            pstmt.setInt(1, 3); pstmt.setString(2, "Carol"); pstmt.setInt(3, 300);
            pstmt.addBatch();
            pstmt.setInt(1, 4); pstmt.setString(2, "Dave"); pstmt.setInt(3, 400);
            pstmt.addBatch();
            pstmt.executeBatch();
        }
        conn.commit();
        System.out.println("[LOCAL READ] SELECT * FROM users ORDER BY id:");
        try (Statement query = conn.createStatement();
             ResultSet rs = query.executeQuery("SELECT id, name, score FROM users ORDER BY id")) {
            while (rs.next()) {
                System.out.println("    id=" + rs.getInt("id") + ", name=" + rs.getString("name")
                        + ", score=" + rs.getInt("score"));
            }
        }
    }

    private void runProductsFlow(Connection conn) throws SQLException {
        banner("TABLE products  --  ALTER TABLE ADD / RENAME / DROP COLUMN");
        try (Statement stmt = conn.createStatement()) {
            System.out.println("[LOCAL DDL] DROP TABLE IF EXISTS products; CREATE TABLE products(id, name, price)");
            stmt.execute("DROP TABLE IF EXISTS products");
            stmt.execute("CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT, price REAL)");
        }
        try (PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO products(id, name, price) VALUES(?, ?, ?)")) {
            System.out.println("[LOCAL] INSERT products (1, Widget, 9.99)");
            pstmt.setInt(1, 1); pstmt.setString(2, "Widget"); pstmt.setDouble(3, 9.99);
            pstmt.executeUpdate();
        }
        conn.commit();
        try (Statement stmt = conn.createStatement()) {
            System.out.println("[LOCAL DDL] ALTER TABLE products ADD COLUMN tag TEXT");
            stmt.execute("ALTER TABLE products ADD COLUMN tag TEXT");
        }
        try (PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO products(id, name, price, tag) VALUES(?, ?, ?, ?)")) {
            System.out.println("[LOCAL] INSERT products using new column (2, Gadget, 19.99, 'new')");
            pstmt.setInt(1, 2); pstmt.setString(2, "Gadget");
            pstmt.setDouble(3, 19.99); pstmt.setString(4, "new");
            pstmt.executeUpdate();
        }
        conn.commit();
        try (Statement stmt = conn.createStatement()) {
            System.out.println("[LOCAL DDL] ALTER TABLE products RENAME COLUMN price TO unit_price");
            stmt.execute("ALTER TABLE products RENAME COLUMN price TO unit_price");
        }
        try (PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO products(id, name, unit_price, tag) VALUES(?, ?, ?, ?)")) {
            System.out.println("[LOCAL] INSERT products using renamed column (3, Sprocket, 29.99, 'gold')");
            pstmt.setInt(1, 3); pstmt.setString(2, "Sprocket");
            pstmt.setDouble(3, 29.99); pstmt.setString(4, "gold");
            pstmt.executeUpdate();
        }
        conn.commit();
        try (Statement stmt = conn.createStatement()) {
            System.out.println("[LOCAL DDL] ALTER TABLE products DROP COLUMN tag");
            stmt.execute("ALTER TABLE products DROP COLUMN tag");
        }
        conn.commit();
        System.out.println("[LOCAL READ] SELECT * FROM products ORDER BY id (post DROP COLUMN tag):");
        try (Statement query = conn.createStatement();
             ResultSet rs = query.executeQuery("SELECT id, name, unit_price FROM products ORDER BY id")) {
            while (rs.next()) {
                System.out.println("    id=" + rs.getInt("id") + ", name=" + rs.getString("name")
                        + ", unit_price=" + rs.getDouble("unit_price"));
            }
        }
    }

    private void runOrdersFlow(Connection conn) throws SQLException {
        banner("TABLE orders -> orders_archive  --  ALTER TABLE RENAME TO");
        try (Statement stmt = conn.createStatement()) {
            System.out.println("[LOCAL DDL] DROP TABLE IF EXISTS orders_archive; DROP TABLE IF EXISTS orders; CREATE TABLE orders(id, product_id, qty)");
            stmt.execute("DROP TABLE IF EXISTS orders_archive");
            stmt.execute("DROP TABLE IF EXISTS orders");
            stmt.execute("CREATE TABLE orders(id INTEGER PRIMARY KEY, product_id INTEGER, qty INTEGER)");
        }
        try (PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO orders(id, product_id, qty) VALUES(?, ?, ?)")) {
            System.out.println("[LOCAL] INSERT orders (1, 1, 5)");
            pstmt.setInt(1, 1); pstmt.setInt(2, 1); pstmt.setInt(3, 5);
            pstmt.executeUpdate();
            System.out.println("[LOCAL] INSERT orders (2, 2, 3)");
            pstmt.setInt(1, 2); pstmt.setInt(2, 2); pstmt.setInt(3, 3);
            pstmt.executeUpdate();
        }
        conn.commit();
        try (Statement stmt = conn.createStatement()) {
            System.out.println("[LOCAL DDL] ALTER TABLE orders RENAME TO orders_archive");
            stmt.execute("ALTER TABLE orders RENAME TO orders_archive");
        }
        try (PreparedStatement pstmt = conn.prepareStatement(
                "INSERT INTO orders_archive(id, product_id, qty) VALUES(?, ?, ?)")) {
            System.out.println("[LOCAL] INSERT orders_archive (3, 3, 7)  -- written via the new name");
            pstmt.setInt(1, 3); pstmt.setInt(2, 3); pstmt.setInt(3, 7);
            pstmt.executeUpdate();
        }
        conn.commit();
        System.out.println("[LOCAL READ] SELECT * FROM orders_archive ORDER BY id:");
        try (Statement query = conn.createStatement();
             ResultSet rs = query.executeQuery("SELECT id, product_id, qty FROM orders_archive ORDER BY id")) {
            while (rs.next()) {
                System.out.println("    id=" + rs.getInt("id") + ", product_id=" + rs.getInt("product_id")
                        + ", qty=" + rs.getInt("qty"));
            }
        }
    }

    private void verifyOnPostgres() throws SQLException {
        banner("VERIFY on PostgreSQL (post awaitSync)");
        try (Connection pg = DriverManager.getConnection(POSTGRES_URL, POSTGRES_USER, POSTGRES_PASSWORD)) {
            try (PreparedStatement pstmt = pg.prepareStatement(
                    "SELECT row_to_json(t)::text FROM (SELECT * FROM "
                  + POSTGRES_SCHEMA + ".users WHERE id = ?) t")) {
                pstmt.setLong(1, 4L);
                try (ResultSet rs = pstmt.executeQuery()) {
                    System.out.println("[POSTGRES] " + POSTGRES_SCHEMA + ".users WHERE id=4 -> "
                            + (rs.next() ? rs.getString(1) : "(no row)"));
                }
            }
            System.out.println("[POSTGRES] " + POSTGRES_SCHEMA
                    + ".products column list (expect: id, name, unit_price; 'tag' dropped, 'price' renamed):");
            try (PreparedStatement pstmt = pg.prepareStatement(
                    "SELECT column_name, data_type FROM information_schema.columns "
                  + "WHERE table_schema = ? AND table_name = 'products' ORDER BY ordinal_position")) {
                pstmt.setString(1, POSTGRES_SCHEMA);
                try (ResultSet rs = pstmt.executeQuery()) {
                    while (rs.next()) System.out.println("    " + rs.getString(1) + "  (" + rs.getString(2) + ")");
                }
            }
            System.out.println("[POSTGRES] " + POSTGRES_SCHEMA + ".products rows:");
            try (Statement q = pg.createStatement();
                 ResultSet rs = q.executeQuery("SELECT id, name, unit_price FROM " + POSTGRES_SCHEMA + ".products ORDER BY id")) {
                while (rs.next()) System.out.println("    id=" + rs.getInt(1) + ", name=" + rs.getString(2)
                        + ", unit_price=" + rs.getDouble(3));
            }
            boolean ordersExists = pgTableExists(pg, "orders");
            boolean ordersArchiveExists = pgTableExists(pg, "orders_archive");
            System.out.println("[POSTGRES] " + POSTGRES_SCHEMA + ".orders exists         -> " + ordersExists
                    + "  (expect false  -- renamed away)");
            System.out.println("[POSTGRES] " + POSTGRES_SCHEMA + ".orders_archive exists -> " + ordersArchiveExists
                    + "  (expect true)");
            if (ordersArchiveExists) {
                System.out.println("[POSTGRES] " + POSTGRES_SCHEMA + ".orders_archive rows:");
                try (Statement q = pg.createStatement();
                     ResultSet rs = q.executeQuery("SELECT id, product_id, qty FROM " + POSTGRES_SCHEMA + ".orders_archive ORDER BY id")) {
                    while (rs.next()) System.out.println("    id=" + rs.getInt(1) + ", product_id=" + rs.getInt(2)
                            + ", qty=" + rs.getInt(3));
                }
            }
        }
    }

    private static boolean pgTableExists(Connection pg, String tableName) throws SQLException {
        try (PreparedStatement pstmt = pg.prepareStatement(
                "SELECT 1 FROM information_schema.tables WHERE table_schema = ? AND table_name = ?")) {
            pstmt.setString(1, POSTGRES_SCHEMA);
            pstmt.setString(2, tableName);
            try (ResultSet rs = pstmt.executeQuery()) { return rs.next(); }
        }
    }

    private static void banner(String text) {
        String bar = "==============================================================";
        System.out.println();
        System.out.println(bar);
        System.out.println(text);
        System.out.println(bar);
    }
}
