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
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import io.synclite.logger.SQLiteStore;
import io.synclite.logger.SyncLiteStore;

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

    public static void main(String[] args) throws ClassNotFoundException, SQLException {
        Class.forName("io.synclite.logger.SQLiteStore");
        Path dbPath = Path.of("sample_store_api.db");
        SQLiteStore.initialize(dbPath, Path.of("synclite.conf"));

        try (SyncLiteStore store = SQLiteStore.open(dbPath)) {
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
            try (Connection conn = DriverManager.getConnection("jdbc:synclite_sqlite_store:sample_store_api.db");
                 Statement ddl = conn.createStatement()) {
                ddl.execute("ALTER TABLE players DROP COLUMN email");
            }

            // 7) DROP TABLE (different table) via Store API
            store.dropTable("temp_players_archive");

            List<Map<String, Object>> rows = store.selectAll("players");
            System.out.println("Store API rows count: " + rows.size());

            // Optional query output for visibility
            try (Connection conn = DriverManager.getConnection("jdbc:synclite_sqlite_store:sample_store_api.db");
                 Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery("SELECT id, name, score FROM players ORDER BY id")) {
                while (rs.next()) {
                    System.out.println("player=" + rs.getInt("id") + ", name=" + rs.getString("name") + ", score=" + rs.getInt("score"));
                }
            }
        }

        SQLiteStore.closeDevice(Path.of("sample_store_api.db"));
    }
}
