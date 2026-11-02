package io.synclite.samples.boot;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.SQLException;

import io.synclite.SQLite;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

/** Verifies that a filtered SyncLite dependency coexists with Boot's Logback provider. */
@SpringBootApplication
public class SpringBootFilterSmokeApplication {
    public static void main(String[] args) {
        SpringApplication.run(SpringBootFilterSmokeApplication.class, args);
    }

    @Bean
    CommandLineRunner verifyLogging() {
        return arguments -> {
            Path root = Files.createTempDirectory("synclite-boot-filter-smoke-");
            Path database = root.resolve("trace.db");
            Path traceDirectory = Path.of(database.toAbsolutePath() + ".synclite");
            Path trace = traceDirectory.resolve("trace.db.trace");
            Files.createDirectories(traceDirectory);

            SQLite.initialize(database, "bootsmoke");
            try {
                if (!Files.isRegularFile(trace)) {
                    throw new IllegalStateException("SyncLite trace file was not created: " + trace);
                }
                try {
                    SQLite.initialize(database, "differentdevice");
                    throw new IllegalStateException("Expected the conflicting device name to be rejected");
                } catch (SQLException expected) {
                    // SyncLite writes this rejected reinitialization to its device trace.
                }
                if (Files.size(trace) == 0) {
                    throw new IllegalStateException("SyncLite trace file has no logged content: " + trace);
                }
            } finally {
                SQLite.closeDevice(database);
            }

            System.out.println("SLF4J_FACTORY=" + LoggerFactory.getILoggerFactory().getClass().getName());
            System.out.println("SYNCLITE_CLASS=" + io.synclite.SQLite.class.getName());
            System.out.println("SYNCLITE_TRACE=" + trace);
        };
    }
}