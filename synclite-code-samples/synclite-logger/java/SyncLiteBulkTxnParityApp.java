import io.synclite.logger.DuckDB;
import io.synclite.logger.SQLite;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

public class SyncLiteBulkTxnParityApp {
    private static final int BATCHES = 10;
    private static final int BATCH_SIZE = 100_000;
    private static final int TOTAL_ROWS = BATCHES * BATCH_SIZE;

    public static void main(String[] args) throws Exception {
        Path root = Paths.get(System.getProperty("java.io.tmpdir"), "synclite-java-bulk-demo", "run-" + System.currentTimeMillis());
        Files.createDirectories(root);

        System.out.println("Demo root: " + root);
        runSqlite(root);
        runDuckDb(root);
    }

    private static void runSqlite(Path root) throws Exception {
        String deviceName = "javabulksqlite";
        Path dbPath = root.resolve("java_bulk_sqlite.db");
        Path confPath = root.resolve("java_bulk_sqlite.conf");
        Path stageDir = root.resolve("stage");

        writeConf(confPath, deviceName, stageDir);

        Class.forName("io.synclite.logger.SQLite");
        Class.forName("org.sqlite.JDBC");

        SQLite.initialize(dbPath, confPath);

        Instant started = Instant.now();
        try (Connection conn = DriverManager.getConnection("jdbc:synclite_sqlite:" + dbPath.toAbsolutePath())) {
            conn.setAutoCommit(false);
            try (Statement st = conn.createStatement()) {
                st.execute("CREATE TABLE IF NOT EXISTS t_bulk_1m (id INTEGER PRIMARY KEY, name TEXT)");
            }
            conn.commit();

            try (PreparedStatement ps = conn.prepareStatement("INSERT INTO t_bulk_1m (id, name) VALUES (?, ?)")) {
                int next = 1;
                for (int batchNo = 1; batchNo <= BATCHES; batchNo++) {
                    int end = next + BATCH_SIZE - 1;
                    for (int id = next; id <= end; id++) {
                        ps.setInt(1, id);
                        ps.setString(2, "sqlite-java-" + id);
                        ps.addBatch();
                    }
                    ps.executeBatch();
                    conn.commit();
                    System.out.println("SQLite progress: batch " + batchNo + "/" + BATCHES + ", inserted " + end + "/" + TOTAL_ROWS);
                    next = end + 1;
                }
            }
        }

        SQLite.closeDevice(dbPath);
        Duration elapsed = Duration.between(started, Instant.now());

        Path stageSubdir = findStageSubdir(stageDir, deviceName);
        int insertTxns = countDistinctInsertCommits(stageSubdir, "t_bulk_1m");
        if (insertTxns != BATCHES) {
            throw new IllegalStateException("SQLite expected " + BATCHES + " insert transactions, found " + insertTxns);
        }

        System.out.println("SQLite insert transactions: " + insertTxns);
        System.out.println("SQLite elapsed: " + elapsed);
        System.out.println("SQLite stage subdir: " + stageSubdir);
    }

    private static void runDuckDb(Path root) throws Exception {
        String deviceName = "javabulkduckdb";
        Path dbPath = root.resolve("java_bulk_duckdb.duckdb");
        Path confPath = root.resolve("java_bulk_duckdb.conf");
        Path stageDir = root.resolve("stage");

        writeConf(confPath, deviceName, stageDir);

        Class.forName("io.synclite.logger.DuckDB");
        Class.forName("org.sqlite.JDBC");

        DuckDB.initialize(dbPath, confPath);

        Instant started = Instant.now();
        try (Connection conn = DriverManager.getConnection("jdbc:synclite_duckdb:" + dbPath.toAbsolutePath())) {
            conn.setAutoCommit(false);
            try (Statement st = conn.createStatement()) {
                st.execute("CREATE TABLE IF NOT EXISTS t_bulk_1m (id INTEGER, name TEXT)");
            }
            conn.commit();

            try (PreparedStatement ps = conn.prepareStatement("INSERT INTO t_bulk_1m (id, name) VALUES (?, ?)")) {
                int next = 1;
                for (int batchNo = 1; batchNo <= BATCHES; batchNo++) {
                    int end = next + BATCH_SIZE - 1;
                    for (int id = next; id <= end; id++) {
                        ps.setInt(1, id);
                        ps.setString(2, "duckdb-java-" + id);
                        ps.addBatch();
                    }
                    ps.executeBatch();
                    conn.commit();
                    System.out.println("DuckDB progress: batch " + batchNo + "/" + BATCHES + ", inserted " + end + "/" + TOTAL_ROWS);
                    next = end + 1;
                }
            }
        }

        DuckDB.closeDevice(dbPath);
        Duration elapsed = Duration.between(started, Instant.now());

        Path stageSubdir = findStageSubdir(stageDir, deviceName);
        int insertTxns = countTxnFilesWithBoundArgs(stageSubdir);
        if (insertTxns != BATCHES) {
            throw new IllegalStateException("DuckDB expected " + BATCHES + " insert transactions, found " + insertTxns);
        }

        System.out.println("DuckDB insert transactions: " + insertTxns);
        System.out.println("DuckDB elapsed: " + elapsed);
        System.out.println("DuckDB stage subdir: " + stageSubdir);
    }

    private static void writeConf(Path confPath, String deviceName, Path stageDir) throws Exception {
        Files.createDirectories(stageDir);
        String body = String.join("\n",
            "device-stage-type=FS",
            "local-data-stage-directory=" + stageDir.toAbsolutePath().toString().replace('\\', '/'),
            "device-name=" + deviceName,
            "log-segment-flush-batch-size=10000",
            ""
        );
        Files.writeString(confPath, body);
    }

    private static Path findStageSubdir(Path stageDir, String deviceName) throws Exception {
        String prefix = "synclite-" + deviceName + "-";
        try (var stream = Files.list(stageDir)) {
            return stream
                .filter(Files::isDirectory)
                .filter(p -> p.getFileName().toString().startsWith(prefix))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("No stage subdir found for prefix: " + prefix));
        }
    }

    private static int countDistinctInsertCommits(Path stageSubdir, String tableName) throws Exception {
        Set<Long> commits = new HashSet<>();
        String like = "INSERT INTO " + tableName + "%";

        try (var stream = Files.list(stageSubdir)) {
            stream
                .filter(Files::isRegularFile)
                .filter(p -> {
                    String n = p.getFileName().toString();
                    return n.endsWith(".sqllog") || n.endsWith(".txn");
                })
                .forEach(p -> {
                    try (Connection c = DriverManager.getConnection("jdbc:sqlite:" + p.toAbsolutePath());
                         PreparedStatement ps = c.prepareStatement("SELECT DISTINCT commit_id FROM commandlog WHERE sql LIKE ?")) {
                        ps.setString(1, like);
                        try (ResultSet rs = ps.executeQuery()) {
                            while (rs.next()) {
                                commits.add(rs.getLong(1));
                            }
                        }
                    } catch (Exception ex) {
                        throw new RuntimeException(ex);
                    }
                });
        }

        return commits.size();
    }

    private static int countTxnFilesWithBoundArgs(Path stageSubdir) throws Exception {
        int count = 0;
        try (var stream = Files.list(stageSubdir)) {
            for (Path p : stream
                .filter(Files::isRegularFile)
                .filter(x -> x.getFileName().toString().endsWith(".txn"))
                .toList()) {
                try (Connection c = DriverManager.getConnection("jdbc:sqlite:" + p.toAbsolutePath());
                     Statement st = c.createStatement();
                     ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM commandlog WHERE arg_cnt > 0")) {
                    if (rs.next() && rs.getLong(1) > 0) {
                        count++;
                    }
                }
            }
        }
        return count;
    }
}
