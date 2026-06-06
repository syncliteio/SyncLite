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
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import io.synclite.logger.SQLiteStore;

/**
 * Store device sample.
 *
 * A store device is for mutable operational data where the row changes are
 * explicit in the operation itself, for example INSERT ... VALUES, UPDATE with
 * concrete column values, and key-based DELETE flows. That lets SyncLite apply
 * those changes directly to downstream destinations instead of replaying the SQL
 * on a replica and harvesting CDC afterward.
 *
 * This is the core difference from a SQL device. A SQL device can accept
 * arbitrary SQL because the consolidator can replay it and derive CDC from the
 * replica. A store device is intentionally narrower, so statements such as
 * INSERT INTO target SELECT ... FROM source are not the model to optimize for,
 * because the inserted rows are not already present in the request.
 */
public class SyncLiteStoreDeviceApp {

    public static void main(String[] args) throws ClassNotFoundException, SQLException {
        Class.forName("io.synclite.logger.SQLiteStore");
        Path dbPath = Path.of("sample_store_sqlite.db");
        SQLiteStore.initialize(dbPath, Path.of("synclite.conf"));

        try (Connection conn = DriverManager.getConnection("jdbc:synclite_sqlite_store:sample_store_sqlite.db")) {
            try (Statement stmt = conn.createStatement()) {
                // 1) CREATE TABLE
                stmt.execute("CREATE TABLE IF NOT EXISTS users(id INT PRIMARY KEY, name TEXT)");

                // Extra table only to demonstrate DROP TABLE on a different table.
                stmt.execute("CREATE TABLE IF NOT EXISTS temp_audit(id INT, note TEXT)");
            }

            // 2) INSERT
            try (PreparedStatement insert = conn.prepareStatement("INSERT INTO users(id, name) VALUES(?, ?)");
                 PreparedStatement update = conn.prepareStatement("UPDATE users SET name = ? WHERE id = ?");
                 PreparedStatement delete = conn.prepareStatement("DELETE FROM users WHERE id = ?");
                 Statement schema = conn.createStatement();
                 Statement query = conn.createStatement()) {
                insert.setInt(1, 1);
                insert.setString(2, "Alice");
                insert.executeUpdate();

                insert.setInt(1, 2);
                insert.setString(2, "Bob");
                insert.executeUpdate();

                // 3) UPDATE
                update.setString(1, "Alice Cooper");
                update.setInt(2, 1);
                update.executeUpdate();

                // 4) DELETE
                delete.setInt(1, 2);
                delete.executeUpdate();

                // 5) ALTER TABLE ADD COLUMN
                schema.execute("ALTER TABLE users ADD COLUMN email TEXT");

                // Fill the newly added column
                try (PreparedStatement fillEmail = conn.prepareStatement("UPDATE users SET email = ? WHERE id = ?")) {
                    fillEmail.setString(1, "alice@example.com");
                    fillEmail.setInt(2, 1);
                    fillEmail.executeUpdate();
                }

                // 6) ALTER TABLE DROP COLUMN
                schema.execute("ALTER TABLE users DROP COLUMN email");

                // 7) DROP TABLE (different table)
                schema.execute("DROP TABLE IF EXISTS temp_audit");

                // Read final data to verify sample flow
                try (ResultSet rs = query.executeQuery("SELECT id, name FROM users ORDER BY id")) {
                    while (rs.next()) {
                        int id = rs.getInt("id");
                        String name = rs.getString("name");
                        System.out.println("user=" + id + ", name=" + name);
                    }
                }
            }
        }

        SQLiteStore.closeDevice(Path.of("sample_store_sqlite.db"));
    }
}
