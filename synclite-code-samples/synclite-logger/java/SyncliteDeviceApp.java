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

import io.synclite.logger.SQLite;

/**
 * SQL device sample.
 *
 * A SQL device accepts general SQL and logs the statements as written. During
 * consolidation those statements are replayed on a replica, CDC is derived from
 * the replica, and that downstream change stream is then applied to the
 * configured destinations.
 *
 * That makes SQL devices the right fit for full relational behavior, including
 * statements whose effects must be computed by the database engine, such as
 * INSERT INTO ... SELECT ... FROM .... Store devices are narrower: they focus on
 * operations where the changed data is already explicit in the request so it can
 * be pushed directly downstream without needing statement replay plus CDC.
 */
public class SyncliteDeviceApp {

    public static void main(String[] args) throws ClassNotFoundException, SQLException {
        appStartup();
        SyncliteDeviceApp app = new SyncliteDeviceApp();
        app.runBusinessLogic();
    }

    public static void appStartup() throws SQLException, ClassNotFoundException {
        // SQL-device default: SQLite.
        // Replace for other SQL-device engines:
        // 1) Driver class: io.synclite.logger.SQLite -> Derby, DuckDB, H2, HyperSQL
        // 2) Initialize call: SQLite.initialize(...) -> <Engine>.initialize(...)
        // 3) JDBC URL prefix in runBusinessLogic():
        //    jdbc:synclite_sqlite: -> jdbc:synclite_derby:, jdbc:synclite_duckdb:, jdbc:synclite_h2:, jdbc:synclite_hsqldb:
        Class.forName("io.synclite.logger.SQLite");
        Path dbPath = Path.of("sample_txn_sqlite.db");
        SQLite.initialize(dbPath, Path.of("synclite.conf"));
    }

    public void runBusinessLogic() throws SQLException {
        try (Connection conn = DriverManager.getConnection("jdbc:synclite_sqlite:sample_txn_sqlite.db")) {
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("CREATE TABLE IF NOT EXISTS feedback(rating INT, comment TEXT)");
                // Separate table for explicit DROP TABLE demonstration.
                stmt.execute("CREATE TABLE IF NOT EXISTS temp_feedback_archive(id INT, note TEXT)");
                stmt.execute("INSERT INTO feedback VALUES(3, 'Good product')");
            }

            conn.setAutoCommit(false);
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("UPDATE feedback SET comment = 'Better product' WHERE rating = 3");
                stmt.execute("INSERT INTO feedback VALUES (1, 'Poor product')");
                stmt.execute("DELETE FROM feedback WHERE rating = 1");
            }
            conn.commit();
            conn.setAutoCommit(true);

            try (PreparedStatement pstmt = conn.prepareStatement("INSERT INTO feedback VALUES(?, ?)")) {
                pstmt.setInt(1, 4);
                pstmt.setString(2, "Excellent Product");
                pstmt.addBatch();

                pstmt.setInt(1, 5);
                pstmt.setString(2, "Outstanding Product");
                pstmt.addBatch();

                pstmt.executeBatch();
            }

            try (Statement schema = conn.createStatement()) {
                // ALTER TABLE ADD COLUMN
                schema.execute("ALTER TABLE feedback ADD COLUMN source TEXT");
            }

            try (PreparedStatement updateSource = conn.prepareStatement("UPDATE feedback SET source = ? WHERE rating = ?")) {
                updateSource.setString(1, "web");
                updateSource.setInt(2, 3);
                updateSource.executeUpdate();
            }

            try (Statement schema = conn.createStatement()) {
                // ALTER TABLE DROP COLUMN
                schema.execute("ALTER TABLE feedback DROP COLUMN source");

                // DROP TABLE on a different table
                schema.execute("DROP TABLE IF EXISTS temp_feedback_archive");
            }

            try (Statement query = conn.createStatement();
                 ResultSet rs = query.executeQuery("SELECT rating, comment FROM feedback ORDER BY rating")) {
                while (rs.next()) {
                    System.out.println("rating=" + rs.getInt("rating") + ", comment=" + rs.getString("comment"));
                }
            }
        }

        SQLite.closeDevice(Path.of("sample_txn_sqlite.db"));
    }
}