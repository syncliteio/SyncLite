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
import io.synclite.SyncLatency;
import io.synclite.SyncLite;
import io.synclite.SyncStatistics;
import io.synclite.SyncStatus;

/**
 * Offline-first SQLite app that syncs every change to PostgreSQL.
 *
 * <p>Java port of {@code samples/rust/synclite_rusqlite_postgres.rs} —
 * same {@code users(id, name, score)} schema and same data flow:
 * drop/create, insert pair, update Bob to 250, batch insert Carol +
 * Dave, read all rows, read local row id=4, force-flush, await sync,
 * then read the same row back from PostgreSQL to prove end-to-end
 * delivery.
 *
 * <p>Run a local PostgreSQL with a database named {@code syncdb} and a
 * schema named {@code syncschema}, then build + run:
 *
 * <pre>
 * (cd synclite-logger-rust         &amp;&amp; cargo build -p synclite-bindings-java)
 * (cd synclite-logger-java/logger        &amp;&amp; mvn -DskipTests install)
 * (cd synclite-logger-java/consolidator  &amp;&amp; mvn -DskipTests package)
 *
 * java -cp synclite-logger-java/consolidator/target/synclite-consolidator-oss.jar:. \
 *      SyncliteSqlitePostgresApp
 * </pre>
 *
 * <p>What you get:
 * <ul>
 *   <li>a normal local SQLite database read/written through plain JDBC
 *       (no network in the hot path),</li>
 *   <li>an in-process consolidator that ships every committed change
 *       to PostgreSQL in the background,</li>
 *   <li>{@code SyncLite.awaitSync(...)} to deterministically block
 *       until the in-flight segment has been applied to PostgreSQL.</li>
 * </ul>
 */
public class SyncliteSqlitePostgresApp {

    private static final Path DB_PATH = Path.of("sample_consolidator_sqlite.db");
    private static final String DEVICE_NAME = "sampledevice";
    private static final String POSTGRES_URL =
            "jdbc:postgresql://localhost:5432/syncdb";
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
            // Closes the Java logger AND stops the in-process Rust consolidator
            // for this device. Idempotent; the consolidator jar also installs
            // a JVM shutdown hook as a safety net.
            SQLite.closeDevice(DB_PATH);
        }
    }

    public static void appStartup() throws SQLException {
        DestinationOptions destination = DestinationOptions.builder()
                .dstType(DstType.POSTGRES)
                .connectionString(POSTGRES_URL)
                .database(POSTGRES_DB)
                .schema(POSTGRES_SCHEMA)
                .syncMode(DstSyncMode.CONSOLIDATION)
                .build();

        // One call wires up the local logger, the segment shipper, and the
        // embedded consolidator that drains into PostgreSQL.
        SQLite.initialize(DB_PATH, DEVICE_NAME, destination);
    }

    public void runBusinessLogic() throws SQLException {
        try (Connection conn = DriverManager.getConnection(
                "jdbc:synclite_sqlite:" + DB_PATH)) {

            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS users");
                stmt.execute(
                    "CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)");
            }

            try (PreparedStatement pstmt = conn.prepareStatement(
                    "INSERT INTO users(id, name, score) VALUES(?, ?, ?)")) {
                pstmt.setInt(1, 1);
                pstmt.setString(2, "Alice");
                pstmt.setInt(3, 100);
                pstmt.executeUpdate();

                pstmt.setInt(1, 2);
                pstmt.setString(2, "Bob");
                pstmt.setInt(3, 200);
                pstmt.executeUpdate();
            }

            try (PreparedStatement pstmt = conn.prepareStatement(
                    "UPDATE users SET score = ? WHERE name = ?")) {
                pstmt.setInt(1, 250);
                pstmt.setString(2, "Bob");
                pstmt.executeUpdate();
            }
            conn.commit();

            try (PreparedStatement pstmt = conn.prepareStatement(
                    "INSERT INTO users(id, name, score) VALUES(?, ?, ?)")) {
                pstmt.setInt(1, 3);
                pstmt.setString(2, "Carol");
                pstmt.setInt(3, 300);
                pstmt.addBatch();

                pstmt.setInt(1, 4);
                pstmt.setString(2, "Dave");
                pstmt.setInt(3, 400);
                pstmt.addBatch();

                pstmt.executeBatch();
            }
            conn.commit();

            try (Statement query = conn.createStatement();
                 ResultSet rs = query.executeQuery(
                         "SELECT id, name, score FROM users ORDER BY id")) {
                while (rs.next()) {
                    System.out.println(
                            "id=" + rs.getInt("id")
                          + ", name=" + rs.getString("name")
                          + ", score=" + rs.getInt("score"));
                }
            }

            try (Statement query = conn.createStatement();
                 ResultSet rs = query.executeQuery(
                         "SELECT id, name, score FROM users WHERE id = 4")) {
                if (rs.next()) {
                    System.out.println(
                            "[READ FROM LOCAL DB] id=" + rs.getInt("id")
                          + ", name=" + rs.getString("name")
                          + ", score=" + rs.getInt("score"));
                } else {
                    System.out.println("[READ FROM LOCAL DB] no row found for id=4");
                }
            }
        }

        // Force the active log segment to roll, then block until the
        // in-process shipper + consolidator have fully applied it to
        // PostgreSQL. Short-lived programs would otherwise exit before
        // the background pipeline gets to drain.
        try {
            SyncLite.awaitSync(DB_PATH, AWAIT_TIMEOUT);
            System.out.println("[SYNC] awaitSync succeeded");
            String row = readRowFromPostgres(4);
            if (row != null) {
                System.out.println("[READ FROM POSTGRESQL POST SYNC] " + row);
            } else {
                System.out.println("[READ FROM POSTGRESQL POST SYNC] no row found for id=4");
            }
        } catch (SQLException e) {
            System.out.println("[SYNC] awaitSync failed: " + e.getMessage());
            throw e;
        }
    }

    private static String readRowFromPostgres(long id) throws SQLException {
        String query = "SELECT row_to_json(t)::text FROM (SELECT * FROM "
                + POSTGRES_SCHEMA + ".users WHERE id = ?) t";
        try (Connection conn = DriverManager.getConnection(
                POSTGRES_URL, POSTGRES_USER, POSTGRES_PASSWORD);
             PreparedStatement pstmt = conn.prepareStatement(query)) {
            pstmt.setLong(1, id);
            try (ResultSet rs = pstmt.executeQuery()) {
                return rs.next() ? rs.getString(1) : null;
            }
        }
    }
}
