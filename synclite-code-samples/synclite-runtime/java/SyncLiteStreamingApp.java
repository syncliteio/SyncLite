/*
 * Copyright (c) 2024 mahendra.chavan@synclite.io, all rights reserved.
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
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Duration;

import io.synclite.DestinationOptions;
import io.synclite.DstSyncMode;
import io.synclite.DstType;
import io.synclite.Streaming;
import io.synclite.SyncLite;

/**
 * Streaming device sample.
 *
 * Streaming devices are for append-first event capture. The normal pattern is
 * to define the stream shape and keep inserting new records that represent
 * events, messages, or telemetry.
 *
 * This is not a mutable relational surface. INSERT is the primary data path,
 * selected DDL is supported for schema evolution, and UPDATE or DELETE are
 * expected to fail because previously emitted events are not meant to be edited
 * in place.
 */
public class SyncLiteStreamingApp {

    private static final Path DB_PATH = Path.of("sample_streaming.db");
    private static final String DEVICE_NAME = "sampledevice";
    private static final String POSTGRES_URL = "jdbc:postgresql://localhost:5432/syncdb";
    private static final String POSTGRES_DB = "syncdb";
    private static final String POSTGRES_SCHEMA = "syncschema";
    private static final Duration AWAIT_TIMEOUT = Duration.ofSeconds(30);

    public static void main(String[] args) throws ClassNotFoundException, SQLException {
        Class.forName("io.synclite.Streaming");

        // PostgreSQL destination (default). Comment out and uncomment one
        // of the alternatives below for SQLite / DuckDB destinations, or
        // for the no-inline-destination path that pairs with a
        // centralized Consolidator service.
        DestinationOptions destination = DestinationOptions.builder()
                .dstType(DstType.POSTGRES)
                .connectionString(POSTGRES_URL)
                .database(POSTGRES_DB)
                .schema(POSTGRES_SCHEMA)
                .syncMode(DstSyncMode.CONSOLIDATION)
                .build();
        Streaming.initialize(DB_PATH, DEVICE_NAME, destination);

        // SQLite destination example:
        // DestinationOptions destination = DestinationOptions.builder()
        //         .dstType(DstType.SQLITE)
        //         .connectionString("dst_sqlite.db")
        //         .build();
        // Streaming.initialize(DB_PATH, DEVICE_NAME, destination);

        // DuckDB destination example:
        // DestinationOptions destination = DestinationOptions.builder()
        //         .dstType(DstType.DUCKDB)
        //         .connectionString("dst_duckdb.duckdb")
        //         .database("dst_duckdb")
        //         .schema("main")
        //         .build();
        // Streaming.initialize(DB_PATH, DEVICE_NAME, destination);

        // Centralized Consolidator path — no inline destination. The
        // device only logs locally; a separate standalone Consolidator
        // service reads the log segments from staging storage and
        // applies them to the configured destination(s):
        // Streaming.initialize(DB_PATH, Path.of("synclite.conf"));

        try (Connection conn = DriverManager.getConnection("jdbc:synclite_streaming:" + DB_PATH)) {
            try (Statement stmt = conn.createStatement()) {
                // 1) CREATE TABLE
                stmt.execute("CREATE TABLE IF NOT EXISTS events(ts BIGINT, event_type TEXT, user_id TEXT)");

                // Separate table to demonstrate DROP TABLE on a different table.
                stmt.execute("CREATE TABLE IF NOT EXISTS temp_events_archive(id INT, note TEXT)");
            }

            // 2) INSERT
            try (PreparedStatement pstmt = conn.prepareStatement("INSERT INTO events VALUES(?, ?, ?)");) {
                pstmt.setLong(1, System.currentTimeMillis());
                pstmt.setString(2, "CLICK");
                pstmt.setString(3, "user-1");
                pstmt.addBatch();

                pstmt.setLong(1, System.currentTimeMillis());
                pstmt.setString(2, "VIEW");
                pstmt.setString(3, "user-2");
                pstmt.addBatch();

                pstmt.executeBatch();
            }

            try (Statement schema = conn.createStatement()) {
                // 3) ALTER TABLE ADD COLUMN
                schema.execute("ALTER TABLE events ADD COLUMN source TEXT");
            }

            try (PreparedStatement insertWithSource = conn.prepareStatement("INSERT INTO events VALUES(?, ?, ?, ?)")) {
                insertWithSource.setLong(1, System.currentTimeMillis());
                insertWithSource.setString(2, "PURCHASE");
                insertWithSource.setString(3, "user-3");
                insertWithSource.setString(4, "mobile");
                insertWithSource.executeUpdate();
            }

            try (Statement schema = conn.createStatement()) {
                // 4) ALTER TABLE DROP COLUMN
                schema.execute("ALTER TABLE events DROP COLUMN source");

                // 5) DROP TABLE on different table
                schema.execute("DROP TABLE IF EXISTS temp_events_archive");
            }

            // Streaming device supports DDL and INSERT only; UPDATE/DELETE are expected to fail.
            try (Statement unsupported = conn.createStatement()) {
                try {
                    unsupported.execute("UPDATE events SET event_type = 'X' WHERE user_id = 'user-1'");
                } catch (SQLException e) {
                    System.out.println("Expected UPDATE failure on Streaming device: " + e.getMessage());
                }

                try {
                    unsupported.execute("DELETE FROM events WHERE user_id = 'user-2'");
                } catch (SQLException e) {
                    System.out.println("Expected DELETE failure on Streaming device: " + e.getMessage());
                }
            }
        }

        // Force the active log segment to roll, then block until the
        // in-process shipper + consolidator have fully applied it to
        // PostgreSQL. Short-lived programs would otherwise exit before
        // the background pipeline gets to drain.
        SyncLite.awaitSync(DB_PATH, AWAIT_TIMEOUT);
        Streaming.closeDevice(DB_PATH);
    }
}
