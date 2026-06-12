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
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import io.synclite.DestinationOptions;
import io.synclite.DstSyncMode;
import io.synclite.DstType;
import io.synclite.SQLiteStore;
import io.synclite.SyncLite;
import io.synclite.SyncLiteStore;

/**
 * Store API sample.
 *
 * This sample uses the Store API rather than issuing raw SQL strings for every
 * change. It targets the same store-device model as the JDBC store sample:
 * mutable operations whose row data is explicit enough to be applied directly to
 * downstream destinations.
 *
 * The contrast with a SQL device is semantic, not just syntactic. A SQL device
 * can log arbitrary SQL and rely on replay plus CDC extraction later. The Store
 * API is intentionally centered on direct CRUD-style changes, so patterns such
 * as INSERT INTO ... SELECT ... are outside its core model. Column drop is still
 * shown through JDBC DDL because Store API has no direct drop-column helper.
 */
public class SyncLiteStoreAPIApp {

    private static final Path DB_PATH = Path.of("sample_store_api.db");
    private static final String DEVICE_NAME = "sampledevicestoreapi";
    private static final String POSTGRES_URL = "jdbc:postgresql://localhost:5432/syncdb";
    private static final String POSTGRES_DB = "syncdb";
    private static final String POSTGRES_SCHEMA = "syncschema";
    private static final Duration AWAIT_TIMEOUT = Duration.ofSeconds(30);

    public static void main(String[] args) throws ClassNotFoundException, SQLException {
        Class.forName("io.synclite.SQLiteStore");

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
        SQLiteStore.initialize(DB_PATH, DEVICE_NAME, destination);

        // SQLite destination example:
        // DestinationOptions destination = DestinationOptions.builder()
        //         .dstType(DstType.SQLITE)
        //         .connectionString("dst_sqlite.db")
        //         .build();
        // SQLiteStore.initialize(DB_PATH, DEVICE_NAME, destination);

        // DuckDB destination example:
        // DestinationOptions destination = DestinationOptions.builder()
        //         .dstType(DstType.DUCKDB)
        //         .connectionString("dst_duckdb.duckdb")
        //         .database("dst_duckdb")
        //         .schema("main")
        //         .build();
        // SQLiteStore.initialize(DB_PATH, DEVICE_NAME, destination);

        // Centralized Consolidator path — no inline destination. The
        // device only logs locally; a separate standalone Consolidator
        // service reads the log segments from staging storage and
        // applies them to the configured destination(s):
        // SQLiteStore.initialize(DB_PATH, Path.of("synclite.conf"));

        try (SyncLiteStore store = SQLiteStore.open(DB_PATH)) {
            // 1) CREATE TABLE via Store API
            Map<String, String> columns = new LinkedHashMap<>();
            columns.put("id", "INTEGER PRIMARY KEY");
            columns.put("name", "TEXT");
            columns.put("score", "INTEGER");
            store.createTable("players", columns);

            // Separate table for explicit DROP TABLE demonstration.
            store.createTable("temp_players_archive", new LinkedHashMap<>(Map.of(
                "id", "INTEGER",
                "note", "TEXT"
            )));

            // 2) INSERT + batch INSERT
            store.insert("players", Map.of("id", 1, "name", "Alice", "score", 100));
            store.insertBatch("players", List.of(
                Map.of("id", 2, "name", "Bob", "score", 200),
                Map.of("id", 3, "name", "Carol", "score", 300)
            ));

            // 3) UPDATE
            store.update("players", Map.of("score", 250), Map.of("name", "Bob"));

            // 4) DELETE
            store.delete("players", Map.of("id", 3));

            // 5) ALTER TABLE ADD COLUMN (implicit via Store API auto-column-add)
            store.update("players", Map.of("email", "alice@example.com"), Map.of("id", 1));

            // 6) ALTER TABLE DROP COLUMN
            // High-level Store API does not expose drop-column directly; execute DDL via JDBC.
            try (Connection conn = DriverManager.getConnection("jdbc:synclite_sqlite_store:" + DB_PATH);
                 Statement ddl = conn.createStatement()) {
                ddl.execute("ALTER TABLE players DROP COLUMN email");
            }

            // 7) DROP TABLE (different table) via Store API
            store.dropTable("temp_players_archive");

            List<Map<String, Object>> rows = store.selectAll("players");
            System.out.println("Store API rows count: " + rows.size());

            // Optional query output for visibility
            try (Connection conn = DriverManager.getConnection("jdbc:synclite_sqlite_store:" + DB_PATH);
                 Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery("SELECT id, name, score FROM players ORDER BY id")) {
                while (rs.next()) {
                    System.out.println("player=" + rs.getInt("id") + ", name=" + rs.getString("name") + ", score=" + rs.getInt("score"));
                }
            }
        }

        // Force the active log segment to roll, then block until the
        // in-process shipper + consolidator have fully applied it to
        // PostgreSQL. Short-lived programs would otherwise exit before
        // the background pipeline gets to drain.
        SyncLite.awaitSync(DB_PATH, AWAIT_TIMEOUT);
        SQLiteStore.closeDevice(DB_PATH);
    }
}
