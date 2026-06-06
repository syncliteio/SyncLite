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
import java.sql.SQLException;
import java.sql.Statement;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import io.synclite.logger.Streaming;
import io.synclite.logger.SyncLiteStream;

/**
 * Stream API sample.
 *
 * This sample uses the Stream API for append-oriented event ingestion. It is the
 * API-level counterpart to the streaming-device JDBC sample and is meant for
 * workloads where new records are emitted continuously.
 *
 * The distinction from Store API is that Stream API is not modeling mutable
 * business rows. It models event flow. INSERT remains the core operation,
 * selected DDL is available for schema evolution, and UPDATE or DELETE are
 * intentionally unsupported.
 */
public class SyncLiteStreamAPIApp {

    public static void main(String[] args) throws ClassNotFoundException, SQLException {
        Class.forName("io.synclite.logger.Streaming");
        Path dbPath = Path.of("sample_stream_api.db");
        Streaming.initialize(dbPath, Path.of("synclite.conf"));

        try (SyncLiteStream stream = SyncLiteStream.open(dbPath)) {
            // 1) CREATE TABLE via Stream API
            stream.createTable("events", new LinkedHashMap<>(Map.of(
                "ts", "BIGINT",
                "event_type", "TEXT",
                "user_id", "TEXT"
            )));

            // Separate table to demonstrate DROP TABLE on a different table.
            stream.createTable("temp_events_archive", new LinkedHashMap<>(Map.of(
                "id", "INT",
                "note", "TEXT"
            )));

            // 2) INSERT + batch INSERT via Stream API
            stream.insert("events", Map.of(
                "ts", System.currentTimeMillis(),
                "event_type", "SIGNUP",
                "user_id", "user-10"
            ));

            stream.insertBatch("events", List.of(
                Map.of("ts", System.currentTimeMillis(), "event_type", "VIEW", "user_id", "user-11"),
                Map.of("ts", System.currentTimeMillis(), "event_type", "CLICK", "user_id", "user-12")
            ));

            // 3) ALTER TABLE ADD COLUMN (implicit via Stream API auto-column-add)
            stream.insert("events", Map.of(
                "ts", System.currentTimeMillis(),
                "event_type", "PURCHASE",
                "user_id", "user-13",
                "source", "web"
            ));

            // 4) ALTER TABLE DROP COLUMN
            // Stream API does not expose drop-column directly; execute DDL via JDBC.
            try (Connection conn = DriverManager.getConnection("jdbc:synclite_streaming:sample_stream_api.db");
                 Statement ddl = conn.createStatement()) {
                ddl.execute("ALTER TABLE events DROP COLUMN source");

                // 5) UPDATE/DELETE are unsupported on streaming devices; demonstrate expected failures.
                try {
                    ddl.execute("UPDATE events SET event_type = 'X' WHERE user_id = 'user-10'");
                } catch (SQLException e) {
                    System.out.println("Expected UPDATE failure on Streaming device: " + e.getMessage());
                }
                try {
                    ddl.execute("DELETE FROM events WHERE user_id = 'user-11'");
                } catch (SQLException e) {
                    System.out.println("Expected DELETE failure on Streaming device: " + e.getMessage());
                }
            }

            // 6) DROP TABLE (different table) via Stream API
            stream.dropTable("temp_events_archive");
        }

        Streaming.closeDevice(Path.of("sample_stream_api.db"));
    }
}
