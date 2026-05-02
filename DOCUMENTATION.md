# SyncLite Platform — Complete Technical Documentation

> **License:** Apache License 2.0  
> **Website:** https://www.synclite.io  
> **Full Online Docs:** https://www.synclite.io/resources/documentation  
> **Community Slack:** https://join.slack.com/t/syncliteworkspace/shared_invite/zt-2pz945vva-uuKapsubC9Mu~uYDRKo6Jw

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Components](#3-components)
4. [Prerequisites & Build](#4-prerequisites--build)
5. [Installation & Quick Start](#5-installation--quick-start)
6. [SyncLite Logger (Java / Python)](#6-synclite-logger-java--python)
   - [Device Types](#61-device-types)
   - [Configuration Reference](#62-configuration-reference-synclite_loggerconf)
   - [Java JDBC API](#63-java-jdbc-api)
   - [SyncLiteStore API](#64-synclitestore-api)
   - [SyncLiteStream API](#65-synclitestream-api)
   - [Jedis (Redis-Compatible) API](#66-jedis-redis-compatible-api)
   - [Kafka Producer API](#67-kafka-producer-api)
   - [Python Usage](#68-python-usage)
   - [Device Encryption](#69-device-encryption)
   - [Command Handler](#610-command-handler)
7. [SyncLite DB (HTTP/JSON Server)](#7-synclite-db-httpjson-server)
   - [Starting the Server](#71-starting-the-server)
   - [HTTP/JSON API Reference](#72-httpjson-api-reference)
   - [Authentication](#73-authentication)
   - [SDK Samples](#74-sdk-samples)
8. [SyncLite Client (CLI)](#8-synclite-client-cli)
9. [SyncLite Consolidator](#9-synclite-consolidator)
   - [Supported Destinations](#91-supported-destinations)
   - [Supported Staging Storages](#92-supported-staging-storages)
   - [Web UI](#93-web-ui)
   - [Consolidator Configuration](#94-consolidator-configuration)
10. [SyncLite DBReader](#10-synclite-dbreader)
    - [Supported Sources](#101-supported-sources)
    - [Replication Modes](#102-replication-modes)
11. [SyncLite QReader (IoT MQTT Connector)](#11-synclite-qreader-iot-mqtt-connector)
    - [Supported Brokers](#111-supported-brokers)
12. [SyncLite Job Monitor](#12-synclite-job-monitor)
13. [SyncLite Validator](#13-synclite-validator)
14. [Sample Web App](#14-sample-web-app)
15. [Staging Storage Setup](#15-staging-storage-setup)
16. [Docker Deployment](#16-docker-deployment)
17. [Release Structure](#17-release-structure)
18. [Security Considerations](#18-security-considerations)
19. [Patent & License](#19-patent--license)

---

## 1. Overview

**SyncLite** is an open-source, low-code relational data synchronization and consolidation platform. It gives developers a single, coherent toolkit to:

- Build **offline-first, sync-ready edge and desktop applications** using embedded databases (SQLite, DuckDB, Apache Derby, H2, HyperSQL) that automatically replicate their data to any cloud destination.
- Stand up **last-mile data streaming pipelines** that ingest at massive scale and deliver into any database, data warehouse, or data lake.
- Configure **database ETL, replication, and migration** pipelines across heterogeneous systems with minimal code.
- Connect **IoT message brokers** to analytical databases in minutes.

### Core Problem SyncLite Solves

Most data integration problems at the edge are solved by one of two approaches:

- **Ship everything to the cloud** and query there — high latency, no offline resilience.
- **Write custom replication code** — brittle, expensive, operationally painful.

SyncLite is a **third way**: embed a lightweight logger that transparently captures every SQL transaction into compact binary log files, ship those files to any staging storage, and let SyncLite Consolidator deliver them in real time to your destination.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Data Producers (Edge / App Layer)                                          │
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │SyncLite      │  │SyncLite DB   │  │SyncLite      │  │SyncLite      │   │
│  │Logger (Java/ │  │(HTTP/JSON    │  │DBReader      │  │QReader       │   │
│  │Python)       │  │server)       │  │(ETL source)  │  │(MQTT IoT)    │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
│         │                 │                  │                  │           │
└─────────┼─────────────────┼──────────────────┼──────────────────┼───────────┘
          │                 │                  │                  │
          ▼                 ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Staging Storage                                                            │
│  (Local FS / SFTP / Amazon S3 / MinIO / Apache Kafka /                     │
│   Microsoft OneDrive / Google Drive / NFS)                                  │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │ compact binary log files / streams
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  SyncLite Consolidator (central always-on sink)                             │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          ▼                        ▼                        ▼
  PostgreSQL / MySQL        Snowflake / BigQuery     Apache Parquet /
  SQL Server / Oracle       Redshift / ClickHouse    Delta Lake / Iceberg
  SQLite / DuckDB …         MongoDB …                CSV on S3 …
```

**Flow:** sources produce compact binary log files → files are shipped to staging storage → SyncLite Consolidator delivers them to one or more destinations in real time.

---

## 3. Components

| Component | Description | Port / URL |
|---|---|---|
| **SyncLite Logger** | Embeddable JDBC driver for Java/Python edge apps | (embedded library — no port) |
| **SyncLite DB** | Standalone HTTP/JSON database server for any language | Configurable (default `5555`) |
| **SyncLite Client** | Interactive CLI for SyncLite devices | (CLI tool — no port) |
| **SyncLite Consolidator** | Central real-time consolidation engine (WAR) | `http://localhost:8080/synclite-consolidator` |
| **SyncLite DBReader** | Database ETL / replication / migration tool (WAR) | `http://localhost:8080/synclite-dbreader` |
| **SyncLite QReader** | IoT MQTT connector (WAR) | `http://localhost:8080/synclite-qreader` |
| **SyncLite Job Monitor** | Unified job management and scheduling UI (WAR) | `http://localhost:8080/synclite-job-monitor` |
| **SyncLite Validator** | End-to-end integration testing tool (WAR) | `http://localhost:8080/synclite-validator` |
| **Sample Web App** | JSP/Servlet demo showing SyncLite Logger in action | `http://localhost:8080/synclite-sample-app` |

---

## 4. Prerequisites & Build

### Prerequisites

| Requirement | Version |
|---|---|
| Java (JDK) | 25 |
| Apache Maven | 3.8.6+ |

> The `bin/deploy.sh` / `bin/deploy.bat` scripts download Apache Tomcat 9.0.117 and OpenJDK 25 automatically. No manual installation needed for a quick start.

### Build the entire platform

```bash
git clone --recurse-submodules git@github.com:syncliteio/SyncLite.git SyncLite
cd SyncLite
mvn -Drevision=oss clean install
```

The release is assembled under `SyncLite/target/synclite-platform-oss/`.

### Build individual components

```bash
# Logger
cd synclite-logger-java/logger
mvn -Drevision=oss clean install

# Consolidator
cd synclite-consolidator/root
mvn -Drevision=oss clean install

# DBReader
cd synclite-dbreader/root
mvn -Drevision=oss clean install

# QReader
cd synclite-qreader/root
mvn -Drevision=oss clean install

# SyncLite DB
cd synclite-db/db
mvn -Drevision=oss clean install

# Client
cd synclite-client/client
mvn -Drevision=oss clean install

# Job Monitor
cd synclite-job-monitor/root
mvn -Drevision=oss clean install

# Validator
cd synclite-validator/root
mvn -Drevision=oss clean install

# Sample Web App
cd synclite-sample-web-app/web
mvn -Drevision=oss clean install
```

---

## 5. Installation & Quick Start

### Native (Windows / Ubuntu)

```bash
cd bin/
./deploy.sh      # or deploy.bat on Windows
./start.sh       # or start.bat on Windows
```

`deploy.sh` / `deploy.bat` automatically:
- Downloads Apache Tomcat 9.0.117
- Downloads OpenJDK 25
- Deploys all SyncLite WAR files into Tomcat

To stop:

```bash
./stop.sh        # or stop.bat on Windows
```

### Available URLs after startup

| URL | App |
|---|---|
| `http://localhost:8080/synclite-consolidator` | Configure and monitor consolidation jobs |
| `http://localhost:8080/synclite-sample-app` | Create devices, run SQL workloads, see live sync |
| `http://localhost:8080/synclite-dbreader` | Set up database ETL/replication pipelines |
| `http://localhost:8080/synclite-qreader` | Set up IoT MQTT connector pipelines |
| `http://localhost:8080/synclite-job-monitor` | Manage and schedule all SyncLite jobs |
| `http://localhost:8080/manager` | Tomcat manager (user: `synclite` / pwd: `synclite`) |

---

## 6. SyncLite Logger (Java / Python)

**SyncLite Logger** is an embeddable Java library (JDBC driver) that makes any Java or Python application sync-ready with minimal code changes. It wraps popular embedded databases and transparently captures every SQL transaction into compact binary log files.

```
Your App  +  SyncLite Logger  +  Embedded DB
     │
     ▼  (SQL log files)
  Staging Storage  (local / SFTP / S3 / MinIO / Kafka / OneDrive / …)
     │
     ▼
  SyncLite Consolidator
     │
     ▼
  Destination DB / Data Warehouse / Data Lake
```

### Adding SyncLite Logger to your project

**Maven:**

```xml
<dependency>
    <groupId>io.synclite</groupId>
    <artifactId>synclite-logger</artifactId>
    <version><!-- latest version --></version>
</dependency>
```

**Jar:** Copy `synclite-logger-<version>.jar` from `lib/logger/java/` in the platform release into your project classpath.

---

### 6.1 Device Types

SyncLite Logger supports multiple **device types**, each targeting a different use case:

#### Transactional Devices (full CRUD — INSERT / UPDATE / DELETE)

| Device Type | JDBC URL Prefix | Embedded DB | Best For |
|---|---|---|---|
| `SQLITE` | `jdbc:synclite_sqlite:` | SQLite | Edge/desktop apps, offline-first, GenAI/RAG |
| `DUCKDB` | `jdbc:synclite_duckdb:` | DuckDB | Analytical edge workloads, columnar data |
| `DERBY` | `jdbc:synclite_derby:` | Apache Derby | Embedded Java enterprise apps |
| `H2` | `jdbc:synclite_h2:` | H2 | Test environments, Spring Boot apps |
| `HYPERSQL` | `jdbc:synclite_hsqldb:` | HyperSQL | Lightweight in-process SQL apps |

#### Appender Devices (INSERT / append-only — high throughput)

| Device Type | JDBC URL Prefix | Embedded DB |
|---|---|---|
| `SQLITE_APPENDER` | `jdbc:synclite_sqlite_appender:` | SQLite |
| `DUCKDB_APPENDER` | `jdbc:synclite_duckdb_appender:` | DuckDB |
| `DERBY_APPENDER` | `jdbc:synclite_derby_appender:` | Apache Derby |
| `H2_APPENDER` | `jdbc:synclite_h2_appender:` | H2 |
| `HYPERSQL_APPENDER` | `jdbc:synclite_hsqldb_appender:` | HyperSQL |

#### Store Devices (CRUD via SyncLiteStore API / Jedis API)

| Device Type | JDBC URL Prefix | Embedded DB |
|---|---|---|
| `SQLITE_STORE` | `jdbc:synclite_sqlite_store:` | SQLite |
| `DUCKDB_STORE` | `jdbc:synclite_duckdb_store:` | DuckDB |
| `DERBY_STORE` | `jdbc:synclite_derby_store:` | Apache Derby |
| `H2_STORE` | `jdbc:synclite_h2_store:` | H2 |
| `HYPERSQL_STORE` | `jdbc:synclite_hsqldb_store:` | HyperSQL |

#### Streaming Device (pure log streaming — no embedded DB)

| Device Type | JDBC URL Prefix | Notes |
|---|---|---|
| `STREAMING` | `jdbc:synclite_streaming:` | In-memory, Kafka Producer / SyncLiteStream API |

---

### 6.2 Configuration Reference (`synclite_logger.conf`)

A full sample configuration file is at `synclite-logger-java/logger/src/main/resources/synclite_logger.conf`. All properties are optional unless noted otherwise.

#### Device Stage Configuration

```properties
# Staging storage type (required)
# Options: FS | SFTP | S3 | MINIO | MS_ONEDRIVE | GOOGLE_DRIVE | KAFKA
destination-type=FS

# Local directory where SyncLite writes log files before shipping to the stage (required)
local-data-stage-directory=/path/to/local/stage

# Local directory for device command files (only when command handler is enabled)
local-command-stage-directory=/path/to/command/stage
```

#### SFTP Configuration

```properties
sftp:host=<sftp-server-hostname>
sftp:port=22
sftp:user-name=<username>
sftp:password=<password>
sftp:remote-data-stage-directory=<remote-data-directory>
sftp:remote-command-stage-directory=<remote-command-directory>
```

#### MinIO Configuration

```properties
minio:endpoint=http://localhost:9000
minio:access-key=<access-key>
minio:secret-key=<secret-key>
minio:data-stage-bucket-name=<bucket-for-data>
minio:command-stage-bucket-name=<bucket-for-commands>
```

#### Amazon S3 Configuration

```properties
s3:endpoint=https://s3.amazonaws.com
s3:access-key=<aws-access-key-id>
s3:secret-key=<aws-secret-access-key>
s3:data-stage-bucket-name=<bucket-for-data>
s3:command-stage-bucket-name=<bucket-for-commands>
```

#### Apache Kafka Configuration

```properties
kafka-producer:bootstrap.servers=localhost:9092,localhost:9093,localhost:9094
# Any additional Kafka producer properties:
kafka-producer:<property-name>=<property-value>

kafka-consumer:bootstrap.servers=localhost:9092,localhost:9093,localhost:9094
# Any additional Kafka consumer properties:
kafka-consumer:<property-name>=<property-value>
```

#### Table Filtering

```properties
# Comma-separated list of tables to include (whitelist)
include-tables=orders,products,customers

# Comma-separated list of tables to exclude (blacklist)
exclude-tables=temp_table,staging_table
```

#### Logger / Performance Tuning

```properties
# Size of the in-memory log queue (default: Integer.MAX_VALUE)
log-queue-size=2147483647

# Number of log records to accumulate before flushing a log segment to disk
log-segment-flush-batch-size=1000000

# Switch to a new log segment after this many log records
log-segment-switch-log-count-threshold=1000000

# Switch to a new log segment after this many milliseconds (5 seconds default)
log-segment-switch-duration-threshold-ms=5000

# How often to ship completed log segments to staging storage (ms)
log-segment-shipping-frequency-ms=5000

# Page size for log segments (bytes)
log-segment-page-size=4096

# Maximum number of SQL arguments inlined in the log (rest are stored separately)
log-max-inlined-arg-count=16

# Whether to use a pre-created database backup (for faster device initialization)
use-precreated-data-backup=false

# Whether to VACUUM the backup database to reduce its size
vacuum-data-backup=true

# Skip restart recovery for non-transactional devices
skip-restart-recovery=false
```

#### Command Handler Configuration

```properties
# Enable device command handler (allows Consolidator to send commands back to the device)
enable-command-handler=false

# INTERNAL: uses built-in handler; EXTERNAL: runs a shell script/batch file
command-handler-type=INTERNAL

# Path to your external command handler script
# <COMMAND> and <COMMAND_FILE> are substituted at runtime
external-command-handler=synclite_command_processor.sh <COMMAND> <COMMAND_FILE>

# How often to poll for new commands (ms)
command-handler-frequency-ms=10000
```

#### Transactional vs. Appender Device Tuning

```properties
# For transactional devices: disable async logging (synchronous mode, maximum durability)
disable-async-logging-for-transactional-device=false

# For appender devices: enable async logging (maximum throughput)
enable-async-logging-for-appender-device=false
```

#### Device Identity

```properties
# Optional human-readable name for this device (shown in Consolidator UI)
device-name=my-edge-device-001
```

---

### 6.3 Java JDBC API

#### Initializing and using a SQLite device

```java
import io.synclite.logger.*;
import java.nio.file.Path;
import java.sql.*;

public class MyEdgeApp {
    public static void main(String[] args) throws Exception {
        Path dbDir  = Path.of(System.getProperty("user.home"), "synclite", "db");
        Path dbPath = dbDir.resolve("myapp.db");
        Path conf   = dbDir.resolve("synclite_logger.conf");

        // Load the SyncLite JDBC driver for SQLite
        Class.forName("io.synclite.logger.SQLite");

        // Initialize SyncLite Logger (reads conf, sets up staging)
        SQLite.initialize(dbPath, conf);

        try (Connection c = DriverManager.getConnection("jdbc:synclite_sqlite:" + dbPath);
             Statement  s = c.createStatement()) {
            s.execute("CREATE TABLE IF NOT EXISTS orders(id INT, item TEXT, qty INT)");
            s.execute("INSERT INTO orders VALUES(1, 'widget', 100)");
            // ↑ each statement is captured in a log file and shipped automatically
        }

        SQLite.closeAll();
    }
}
```

#### Switching the embedded database engine

Replace `SQLite` / `synclite_sqlite` with the corresponding class and URL prefix:

| Engine | Driver Class | JDBC URL Prefix |
|---|---|---|
| SQLite | `io.synclite.logger.SQLite` | `jdbc:synclite_sqlite:` |
| DuckDB | `io.synclite.logger.DuckDB` | `jdbc:synclite_duckdb:` |
| Apache Derby | `io.synclite.logger.Derby` | `jdbc:synclite_derby:` |
| H2 | `io.synclite.logger.H2` | `jdbc:synclite_h2:` |
| HyperSQL | `io.synclite.logger.HyperSQL` | `jdbc:synclite_hsqldb:` |

#### PreparedStatement and batch operations

```java
try (Connection c = DriverManager.getConnection("jdbc:synclite_sqlite:" + dbPath);
     PreparedStatement ps = c.prepareStatement("INSERT INTO events(ts, type) VALUES(?, ?)")) {
    for (int i = 0; i < 1000; i++) {
        ps.setLong(1, System.currentTimeMillis());
        ps.setString(2, "event-" + i);
        ps.addBatch();
    }
    ps.executeBatch();
}
```

#### Appender device (high-throughput, append-only)

```java
Class.forName("io.synclite.logger.SQLiteAppender");
SQLiteAppender.initialize(dbPath, conf);

try (Connection c = DriverManager.getConnection("jdbc:synclite_sqlite_appender:" + dbPath);
     PreparedStatement ps = c.prepareStatement("INSERT INTO logs(ts, msg) VALUES(?, ?)")) {
    ps.setLong(1, System.currentTimeMillis());
    ps.setString(2, "high-throughput record");
    ps.addBatch();
    ps.executeBatch();
}
SQLiteAppender.closeAll();
```

---

### 6.4 SyncLiteStore API

**STORE devices** expose a typed, schema-evolution-aware CRUD API. No raw SQL required. Missing columns are automatically added when a new key appears in an `insert` / `update` map.

```java
import io.synclite.logger.SQLiteStore;
import io.synclite.logger.SyncLiteStore;
import java.util.*;
import java.nio.file.Path;

Class.forName("io.synclite.logger.SQLiteStore");
Path dbPath = Path.of("mystore.db");
SQLiteStore.initialize(dbPath, Path.of("synclite_logger.conf"));

try (SyncLiteStore store = SQLiteStore.open(dbPath)) {

    // CREATE TABLE (schema defined as ordered map for deterministic column order)
    store.createTable("players", new LinkedHashMap<>(Map.of(
        "id",    "INTEGER PRIMARY KEY",
        "name",  "TEXT",
        "score", "INTEGER"
    )));

    // INSERT — single row
    store.insert("players", Map.of("id", 1, "name", "Alice", "score", 100));

    // INSERT — batch
    store.insertBatch("players", List.of(
        Map.of("id", 2, "name", "Bob",   "score", 200),
        Map.of("id", 3, "name", "Carol", "score", 300)
    ));

    // UPDATE — set new values where condition matches
    // (if "score" column doesn't exist yet, it's auto-added)
    store.update("players", Map.of("score", 250), Map.of("name", "Bob"));

    // DELETE — delete rows matching condition
    store.delete("players", Map.of("id", 3));

    // SELECT — reads from the local embedded DB (not replicated)
    List<Map<String, Object>> rows = store.selectAll("players");
    for (Map<String, Object> row : rows) {
        System.out.println(row);
    }
}
SQLiteStore.closeDevice(dbPath);
```

The same API is available for DuckDB, Derby, H2, and HyperSQL backends — replace `SQLiteStore` with `DuckDBStore`, `DerbyStore`, `H2Store`, or `HyperSQLStore`.

---

### 6.5 SyncLiteStream API

`SyncLiteStream` wraps the `STREAMING` device with a fluent append-only API. UPDATE and DELETE are intentionally absent — this models event flow, not mutable records.

```java
import io.synclite.logger.Streaming;
import io.synclite.logger.SyncLiteStream;
import java.util.*;
import java.nio.file.Path;

Class.forName("io.synclite.logger.Streaming");
Path dbPath = Path.of("events.db");
Streaming.initialize(dbPath, Path.of("synclite_logger.conf"));

try (SyncLiteStream stream = SyncLiteStream.open(dbPath)) {

    // Create a table (only if it doesn't exist)
    stream.createTable("events", new LinkedHashMap<>(Map.of(
        "ts",         "BIGINT",
        "event_type", "TEXT",
        "user_id",    "TEXT"
    )));

    // Single insert
    stream.insert("events", Map.of(
        "ts",         System.currentTimeMillis(),
        "event_type", "SIGNUP",
        "user_id",    "user-10"
    ));

    // Batch insert — new columns (e.g. "source") are auto-added on first occurrence
    stream.insertBatch("events", List.of(
        Map.of("ts", System.currentTimeMillis(), "event_type", "VIEW",     "user_id", "user-11", "source", "web"),
        Map.of("ts", System.currentTimeMillis(), "event_type", "PURCHASE", "user_id", "user-12", "source", "app")
    ));

    // Drop a table
    stream.dropTable("events");
}
```

---

### 6.6 Jedis (Redis-Compatible) API

`io.synclite.logger.Jedis` is a drop-in subclass of the `redis.clients.jedis.Jedis` class. Every write is **durably committed to a `SQLITE_STORE` SyncLite device** before being forwarded to Redis. On the next startup the cache is automatically repopulated from the store, so Redis data survives restarts. All captured mutations flow through SyncLite Consolidator to any downstream destination.

#### Managed mode (Jedis handles SyncLiteStore lifecycle)

```java
import io.synclite.logger.Jedis;
import java.nio.file.Path;

Path dbPath = Path.of("cache.db");
Path conf   = Path.of("synclite_logger.conf");

try (Jedis jedis = Jedis.builder(dbPath, conf, "cache-device")
        .host("localhost")
        .port(6379)
        .build()) {

    // String operations
    jedis.set("user:1:name", "Alice");
    String name = jedis.get("user:1:name");

    // Hash operations
    jedis.hset("session:42", Map.of("token", "abc123", "status", "active"));

    // List operations
    jedis.rpush("queue", "job-1", "job-2");

    // Set operations
    jedis.sadd("tags", "etl", "cdc");

    // Sorted set operations
    jedis.zadd("leaderboard", Map.of("Alice", 100.0, "Bob", 200.0));

    // Key expiry
    jedis.expire("session:42", 3600);

    // Delete
    jedis.del("tmp");
}
```

#### External-store mode (supply a pre-opened SyncLiteStore)

```java
try (SyncLiteStore store = SQLiteStore.open(dbPath)) {
    try (Jedis jedis = Jedis.builder(store)
            .host("localhost").port(6379).build()) {
        jedis.set("key", "value");
    }
}
```

---

### 6.7 Kafka Producer API

`io.synclite.logger.KafkaProducer` is a drop-in replacement for `org.apache.kafka.clients.producer.KafkaProducer`. It accepts the same `Properties` map and `ProducerRecord` arguments that standard Kafka producer code uses, but durably persists every record to a `STREAMING` SyncLite device before forwarding to the broker. This lets you adopt SyncLite persistence behind existing Kafka producer code with no structural changes.

```java
import io.synclite.logger.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import java.nio.file.Path;
import java.util.Properties;

Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9092");

// SyncLite-specific: path and type of the local STREAMING device
props.put("device-path", Path.of("sample_kafka_device.db").toAbsolutePath().toString());
props.put("device-type", "STREAMING");

try (KafkaProducer producer = new KafkaProducer(props)) {
    producer.send(new ProducerRecord<>("orders", "order-1", "{\"status\":\"created\"}"));
    producer.send(new ProducerRecord<>("orders", "order-2", "{\"status\":\"confirmed\"}"));
    producer.flush();
}
```

**How it differs from the STREAMING JDBC approach (section 6.3):** JDBC models messages as SQL rows (INSERT statements). `KafkaProducer` models them as topic/key/value records — the natural shape for applications already built around Kafka producer semantics. Both approaches ultimately write to a `STREAMING` device and flow through SyncLite Consolidator to the destination.

---

### 6.8 Python Usage

SyncLite Logger can be used from Python via two bridge libraries: **JayDeBeApi** (SQL / JDBC style) and **JPype** (direct Java API calls). Use JayDeBeApi for standard SQL workloads; use JPype when you need the higher-level `SyncLiteStore` or `SyncLiteStream` APIs.

#### JayDeBeApi — SQL (JDBC-style)

```python
import jaydebeapi, jpype

jar = "/path/to/synclite-logger-<version>.jar"
jpype.startJVM(jpype.getDefaultJVMPath(), f"-Djava.class.path={jar}", convertStrings=True)

conn = jaydebeapi.connect(
    "io.synclite.logger.SQLite",
    "jdbc:synclite_sqlite:/home/alice/synclite/db/myapp.db",
    {"config": "/home/alice/synclite/synclite_logger.conf"},
    jar
)
cur = conn.cursor()
cur.execute("CREATE TABLE IF NOT EXISTS events(id INT, payload TEXT)")
cur.execute("INSERT INTO events VALUES(1, 'hello from Python')")
conn.commit()
conn.close()
```

#### JPype — `SyncLiteStore` API

```python
import jpype, jpype.imports
jpype.startJVM(classpath=["/path/to/synclite-logger-<version>.jar"])

from io.synclite.logger import SQLiteStore, SyncLiteStore
from java.nio.file import Paths
from java.util import LinkedHashMap

db   = Paths.get("/home/alice/synclite/db/mystore.db")
conf = Paths.get("/home/alice/synclite/synclite_logger.conf")
SQLiteStore.initialize(db, conf)

with SyncLiteStore.open(db) as store:
    cols = LinkedHashMap()
    cols.put("id", "INTEGER PRIMARY KEY")
    cols.put("name", "TEXT")
    store.createTable("users", cols)
    store.insert("users", {"id": 1, "name": "Alice"})

SQLiteStore.closeDevice(db)
jpype.shutdownJVM()
```

#### JPype — `SyncLiteStream` API

```python
import jpype, jpype.imports
jpype.startJVM(classpath=["/path/to/synclite-logger-<version>.jar"])

from io.synclite.logger import Streaming, SyncLiteStream
from java.nio.file import Paths
from java.util import LinkedHashMap

db   = Paths.get("/home/alice/synclite/db/events.db")
conf = Paths.get("/home/alice/synclite/synclite_logger.conf")
Streaming.initialize(db, conf)

with SyncLiteStream.open(db) as stream:
    cols = LinkedHashMap()
    cols.put("ts",         "BIGINT")
    cols.put("event_type", "TEXT")
    stream.createTable("events", cols)
    stream.insert("events", {"ts": 1714200000000, "event_type": "SIGNUP"})

jpype.shutdownJVM()
```

---

### 6.9 Device Encryption

SyncLite Logger supports transparent encryption of log files before they are shipped to staging storage. Configure encryption in `synclite_logger.conf`:

```properties
# Path to the encryption public key file (DER format).
# The mere presence of this property enables encryption — there is no separate enable flag.
# The file must already exist; SyncLite Logger will NOT generate it automatically
# and will throw an error at initialization if the path does not exist.
device-encryption-key-file=/path/to/synclite_public_key.der
```

When encryption is enabled:
- Log files are encrypted on the edge device before shipping.
- SyncLite Consolidator decrypts them upon receipt (the corresponding private key must be registered in the Consolidator job configuration).
- The local database file itself is **not** encrypted — only the shipped log files.

---

### 6.10 Command Handler

The **Command Handler** enables bi-directional communication: SyncLite Consolidator drops command files into the command stage directory, and the logger polls that directory on a fixed interval, reads the files, and dispatches them — either to your Java callback (`INTERNAL`) or to a shell script (`EXTERNAL`).

Each command file is named `<timestamp>.<command-text>`. The logger processes them in timestamp order, exactly once (it remembers the last processed timestamp across restarts).

#### `synclite_logger.conf` settings

```properties
enable-command-handler=true

# INTERNAL — your Java code handles the command via a registered callback
# EXTERNAL — the logger invokes a shell script / batch file
command-handler-type=INTERNAL

# How often to poll the command stage directory for new command files (ms)
command-handler-frequency-ms=10000

# Required only when command-handler-type=EXTERNAL
# <COMMAND> is replaced with the command text (the part after the dot in the filename)
# <COMMAND_FILE> is replaced with the full path to the command file
external-command-handler=synclite_command_processor.sh <COMMAND> <COMMAND_FILE>

# Required: the local directory where command files are received from the stage
local-command-stage-directory=/path/to/local/command/stage
```

#### `INTERNAL` type — Java callback

For `INTERNAL`, you must register a `SyncLiteCommandHandlerCallback` implementation **before** calling `initialize()`. If no callback is registered, `initialize()` throws a `SQLException`.

```java
import io.synclite.logger.*;
import java.nio.file.Path;

// 1. Implement the callback interface
SyncLiteCommandHandlerCallback myHandler = (command, commandFile) -> {
    System.out.println("Received command: " + command);
    System.out.println("Command file: " + commandFile);

    switch (command) {
        case "PURGE_OLD_RECORDS":
            // e.g. delete rows older than 30 days
            try (Connection c = DriverManager.getConnection("jdbc:synclite_sqlite:" + dbPath);
                 Statement s = c.createStatement()) {
                s.execute("DELETE FROM events WHERE ts < " + (System.currentTimeMillis() - 30L * 86400_000));
            } catch (Exception e) {
                e.printStackTrace();
            }
            break;
        case "RELOAD_CONFIG":
            // reload application configuration from disk
            break;
        default:
            System.out.println("Unknown command: " + command);
    }
};

// 2. Wire the callback into SyncLiteOptions
SyncLiteOptions options = new SyncLiteOptions();
options.setCommandHandlerCallback(myHandler);
// (load the rest of the options from your conf file or set programmatically)

// 3. Initialize — the command handler thread starts automatically
Path dbPath = Path.of("myapp.db");
SQLite.initialize(DeviceType.SQLITE, dbPath, options);
```

The logger starts a background scheduler that calls `myHandler.handleCommand(commandText, commandFilePath)` each time a new command file appears.

#### `EXTERNAL` type — shell script

For `EXTERNAL`, the logger calls `Runtime.exec()` with your configured command, substituting placeholders:

```properties
command-handler-type=EXTERNAL
external-command-handler=/opt/scripts/synclite_command_processor.sh <COMMAND> <COMMAND_FILE>
```

When a command file named `1714200000000.PURGE_OLD_RECORDS` arrives, the logger executes:

```bash
/opt/scripts/synclite_command_processor.sh PURGE_OLD_RECORDS "/path/to/stage/commands/1714200000000.PURGE_OLD_RECORDS"
```

Example script:

```bash
#!/bin/bash
COMMAND="$1"
COMMAND_FILE="$2"

case "$COMMAND" in
    PURGE_OLD_RECORDS)
        sqlite3 /home/alice/synclite/db/myapp.db \
            "DELETE FROM events WHERE ts < $(($(date +%s%3N) - 2592000000));"
        ;;
    RELOAD_CONFIG)
        systemctl reload myapp.service
        ;;
    *)
        echo "Unknown command: $COMMAND" >&2
        exit 1
        ;;
esac
```

The logger waits for the process to exit before marking the command as processed.

#### Key behaviour facts (from source code)

| Fact | Detail |
|---|---|
| Command ordering | Files are sorted by the timestamp prefix and executed in ascending order |
| At-least-once delivery | The last processed timestamp is persisted in the device metadata; commands with a lower timestamp are skipped on the next poll |
| No callback → error | `INTERNAL` without a registered callback causes `initialize()` to throw `SQLException` immediately |
| File deleted after execution | The command file is deleted from the local command stage after successful processing |
| Error resilience | If execution throws, the error is logged and the handler continues on the next poll cycle |

---

## 7. SyncLite DB (HTTP/JSON Server)

**SyncLite DB** is a standalone database server that wraps the same embedded databases (SQLite, DuckDB, Derby, H2, HyperSQL) and exposes them over HTTP as a JSON API — making SyncLite accessible to **any programming language**.

```
Your App (any language)  ──HTTP/JSON──▶  SyncLite DB Server  ──▶  Staging Storage  ──▶  SyncLite Consolidator  ──▶  Destination
```

### 7.1 Starting the Server

```bash
# Linux / macOS
cd tools/synclite-db/
./synclite-db.sh --config synclite_db.conf

# Windows
synclite-db.bat --config synclite_db.conf
```

The server binds to `http://localhost:<port>/synclite` (port configured in `synclite_db.conf`).

---

### 7.2 HTTP/JSON API Reference

All requests are `POST /synclite` with a JSON body.

#### Initialize a database

```json
{
  "db-type": "SQLITE",
  "db-path": "/home/alice/synclite/job1/myapp.db",
  "synclite-logger-config": "/home/alice/synclite/job1/synclite_logger.conf",
  "sql": "initialize"
}
```

**`db-type` values:** `SQLITE` · `DUCKDB` · `DERBY` · `H2` · `HYPERSQL` · `STREAMING` · `SQLITE_APPENDER` · `DUCKDB_APPENDER` · `DERBY_APPENDER` · `H2_APPENDER` · `HYPERSQL_APPENDER`

#### DDL — Create a table

```json
{
  "db-path": "/home/alice/synclite/job1/myapp.db",
  "sql": "CREATE TABLE IF NOT EXISTS events(id INT, payload TEXT)"
}
```

#### DML — Insert (with positional parameters)

```json
{
  "db-path": "/home/alice/synclite/job1/myapp.db",
  "sql": "INSERT INTO events VALUES(?, ?)",
  "arguments": [[1, "edge-event-1"], [2, "edge-event-2"]]
}
```

Each sub-array in `arguments` is one row. This performs a batch insert in a single HTTP call.

#### Explicit transaction

```json
// 1. Begin — response contains "txn-handle"
{ "db-path": "...", "sql": "begin" }

// 2. Execute inside transaction
{
  "db-path": "...",
  "sql": "INSERT INTO events VALUES(?, ?)",
  "txn-handle": "<uuid-from-begin-response>",
  "arguments": [[3, "three"]]
}

// 3. Commit
{ "db-path": "...", "sql": "commit", "txn-handle": "<uuid>" }

// 3. (alternatively) Rollback
{ "db-path": "...", "sql": "rollback", "txn-handle": "<uuid>" }
```

#### SELECT — basic query

```json
{
  "db-path": "/home/alice/synclite/job1/myapp.db",
  "sql": "SELECT id, name, score FROM players ORDER BY id",
  "resultset-include-metadata": "ON"
}
```

**Response:**

```json
{
  "result": true,
  "message": "OK",
  "column-metadata": [
    { "label": "id",    "type": "INTEGER" },
    { "label": "name",  "type": "TEXT"    },
    { "label": "score", "type": "INTEGER" }
  ],
  "resultset": [
    { "id": 1, "name": "Alice", "score": 100 },
    { "id": 2, "name": "Bob",   "score": 200 }
  ],
  "has-more": false
}
```

#### SELECT — paginated (large result sets)

**Step 1 — Initial request with page size:**

```json
{
  "db-path": "...",
  "sql": "SELECT id, name, score FROM players ORDER BY id",
  "resultset-pagination-size": 100,
  "resultset-include-metadata": "ON"
}
```

**Response (first page):**

```json
{
  "result": true,
  "column-metadata": [...],
  "resultset": [...],
  "resultset-handle": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "has-more": true
}
```

**Step 2 — Fetch next page:**

```json
{
  "request-type": "next",
  "resultset-handle": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "resultset-pagination-size": 100
}
```

Repeat until `"has-more": false`. The handle is automatically released on the last page.

#### SELECT — columnar (DB data format)

Pass `"resultset-data-format": "DB"` to receive rows as value arrays instead of `{name: value}` objects — smaller payloads for wide tables:

```json
{
  "db-path": "...",
  "sql": "SELECT id, name, score FROM players ORDER BY id",
  "resultset-data-format": "DB",
  "resultset-include-metadata": "ON"
}
```

**Response:**

```json
{
  "result": true,
  "column-metadata": [{ "label": "id" }, { "label": "name" }, { "label": "score" }],
  "resultset": [
    [1, "Alice", 100],
    [2, "Bob",   200]
  ],
  "has-more": false
}
```

#### Close a database

```json
{ "db-path": "...", "sql": "close" }
```

#### Common response fields

| Field | Description |
|---|---|
| `result` | `true` on success, `false` on error |
| `message` | Human-readable status or error message |
| `resultset` | Array of row objects or arrays (SELECT only) |
| `column-metadata` | Array of `{label, type}` objects (when `resultset-include-metadata: "ON"`) |
| `resultset-handle` | UUID for paginated result sets (`has-more: true`) |
| `has-more` | `true` if more pages exist |
| `txn-handle` | Transaction UUID (begin/commit/rollback) |

---

### 7.3 Authentication

SyncLite DB supports two authentication modes, both configured in `synclite_db.conf`. They are independent — you can use one, both, or neither depending on your security requirements.

---

#### Mode 1 — Global Token (`X-SyncLite-Token`)

A single shared secret token. Every request that carries the correct token is accepted.

**Server configuration (`synclite_db.conf`):**

```properties
# Set a long, random token (change this!)
auth-token = change-me
```

**Client — send the token as a custom HTTP header:**

```
X-SyncLite-Token: change-me
```

Python example:

```python
import requests

headers = {"X-SyncLite-Token": "change-me"}
requests.post("http://localhost:5555/synclite",
              json={"db-path": "/tmp/myapp.db", "sql": "SELECT 1"},
              headers=headers)
```

The environment variable `SYNCLITE_DB_AUTH_TOKEN` is the conventional way all SDK samples pick up this token at runtime.

---

#### Mode 2 — Per-App HMAC Signed Requests (`app-auth`)

Each registered application has its own `app-id` and `app-secret`. Every request is signed with HMAC-SHA256 over a canonical string that includes the timestamp, a nonce, and the SHA-256 hash of the request body. This prevents replay attacks and protects against body tampering.

**Server configuration (`synclite_db.conf`):**

```properties
# Enable per-application signed-request authentication
enable-app-auth = true

# Allowed clock drift between client and server
app-auth-timestamp-skew-ms = 300000

# How long a nonce is remembered (blocks replays within this window)
app-auth-nonce-ttl-ms = 600000

# Max nonce entries held in memory for replay protection
app-auth-nonce-cache-max-entries = 10000

# Comma-separated list of registered app IDs
authorized-apps = app1,app2

# Per-app secrets and allowed operations
app.app1.secret = replace-with-long-random-secret
app.app1.allowed-ops = initialize,begin,commit,rollback,select,next,execute,close

app.app2.secret = replace-with-long-random-secret
app.app2.allowed-ops = select,next,execute   # read-only + DML, no lifecycle ops
```

**`allowed-ops` values:** `initialize` · `close` · `begin` · `commit` · `rollback` · `select` · `next` · `execute`

**How the client signs a request:**

For every request the client:

1. Serialises the JSON body to a compact string (`payload`).
2. Computes `bodyHash = SHA-256(payload)` as a lowercase hex string.
3. Builds a canonical string:
   ```
   POST\n/\n<timestamp-ms>\n<nonce>\n<bodyHash>
   ```
4. Computes `signature = Base64( HMAC-SHA256(appSecret, canonical) )`.
5. Sends four extra HTTP headers:

| Header | Value |
|---|---|
| `X-SyncLite-App-Id` | The app's registered ID (e.g. `app1`) |
| `X-SyncLite-Timestamp` | Unix timestamp in milliseconds (UTC) |
| `X-SyncLite-Nonce` | A unique random string per request (e.g. UUID) |
| `X-SyncLite-Signature` | Base64-encoded HMAC-SHA256 signature |

Python example (no SDK):

```python
import requests, hashlib, hmac, base64, time, uuid

APP_ID     = "app1"
APP_SECRET = "replace-with-long-random-secret"
BASE_URL   = "http://localhost:5555/synclite"

def signed_post(payload: dict) -> dict:
    import json
    body      = json.dumps(payload, separators=(",", ":"))
    timestamp = str(int(time.time() * 1000))
    nonce     = str(uuid.uuid4())
    body_hash = hashlib.sha256(body.encode()).hexdigest()
    canonical = f"POST\n/\n{timestamp}\n{nonce}\n{body_hash}"
    sig       = base64.b64encode(
                    hmac.new(APP_SECRET.encode(), canonical.encode(), hashlib.sha256).digest()
                ).decode()
    headers = {
        "Content-Type":       "application/json",
        "X-SyncLite-App-Id":  APP_ID,
        "X-SyncLite-Timestamp": timestamp,
        "X-SyncLite-Nonce":   nonce,
        "X-SyncLite-Signature": sig,
    }
    return requests.post(BASE_URL, data=body, headers=headers).json()

result = signed_post({"db-path": "/tmp/myapp.db", "sql": "SELECT 1"})
```

Java example (same canonical format):

```java
String payload   = jsonBody;   // compact JSON string
String timestamp = String.valueOf(System.currentTimeMillis());
String nonce     = UUID.randomUUID().toString();
String bodyHash  = sha256Hex(payload);  // lowercase hex
String canonical = "POST\n/\n" + timestamp + "\n" + nonce + "\n" + bodyHash;

Mac mac = Mac.getInstance("HmacSHA256");
mac.init(new SecretKeySpec(appSecret.getBytes(UTF_8), "HmacSHA256"));
String signature = Base64.getEncoder().encodeToString(mac.doFinal(canonical.getBytes(UTF_8)));

// Set headers on the HTTP request:
// X-SyncLite-App-Id, X-SyncLite-Timestamp, X-SyncLite-Nonce, X-SyncLite-Signature
```

The environment variables `SYNCLITE_DB_APP_ID` and `SYNCLITE_DB_APP_SECRET` are the conventional way all SDK samples pick up credentials at runtime.

---

#### Security notes

- Use HTTPS (reverse proxy with TLS) in any network-exposed deployment — neither mode encrypts the transport layer itself.
- Choose a long, random value for `auth-token` and all `app.*.secret` entries.
- `app-auth` is strictly stronger than the global token: it scopes permissions per application, prevents replay attacks via the nonce cache, and detects body tampering via the SHA-256 body hash in the signature.

---

### 7.4 SDK Samples

Ready-to-run client code samples are in `synclite-db/sdk-source/`:

| Language | Directory |
|---|---|
| Java | `sdk-source/java/` |
| Python | `sdk-source/python/` |
| C# | `sdk-source/c#/` |
| C++ | `sdk-source/cpp/` |
| Go | `sdk-source/go/` |
| Rust | `sdk-source/rust/` |
| Ruby | `sdk-source/ruby/` |
| Node.js | `sdk-source/node.js/` |

See `sdk-source/GETTING_STARTED.md` for run instructions and `sdk-source/LANGUAGE_QUICKSTART.md` for per-language setup.

**Python example (no SDK — plain HTTP):**

```python
import requests

BASE = "http://localhost:5555/synclite"

# Initialize
requests.post(BASE, json={
    "db-type": "SQLITE",
    "db-path": "/tmp/myapp.db",
    "synclite-logger-config": "/tmp/synclite_logger.conf",
    "sql": "initialize"
})

# Create table
requests.post(BASE, json={
    "db-path": "/tmp/myapp.db",
    "sql": "CREATE TABLE IF NOT EXISTS t1(a INT, b TEXT)"
})

# Batch insert
requests.post(BASE, json={
    "db-path": "/tmp/myapp.db",
    "sql": "INSERT INTO t1 VALUES(?, ?)",
    "arguments": [[1, "hello"], [2, "world"]]
})
```

---

## 8. SyncLite Client (CLI)

**SyncLite Client** is an interactive command-line SQL client for SyncLite devices.

### Connection Modes

| Mode | Description |
|---|---|
| **Embedded** (default) | Uses SyncLite Logger JDBC in-process |
| **Remote** (HTTP) | Connects to a running SyncLite DB server |

### Usage

```bash
# Windows — default device at %USERPROFILE%\synclite\job1\db\test.db (SQLITE)
synclite-cli.bat

# Linux / macOS — default device
synclite-cli.sh

# Explicit path and type
synclite-cli.sh /path/to/myapp.db \
    --device-type SQLITE \
    --synclite-logger-config /path/to/synclite_logger.conf

# Remote mode (via SyncLite DB server)
synclite-cli.sh /path/to/myapp.db \
    --device-type SQLITE \
    --synclite-logger-config /path/to/synclite_logger.conf \
    --server http://localhost:5555
```

### Supported Device Types

`SQLITE` · `DUCKDB` · `DERBY` · `H2` · `HYPERSQL` · `STREAMING` · `SQLITE_APPENDER` · `DUCKDB_APPENDER` · `DERBY_APPENDER` · `H2_APPENDER` · `HYPERSQL_APPENDER`

### Interactive Session Example

```
$ synclite-cli.sh ~/synclite/db/myapp.db --device-type SQLITE
Connected to SyncLite SQLITE device: /home/alice/synclite/db/myapp.db
Type SQL statements, or 'exit' to quit.

SyncLite> CREATE TABLE IF NOT EXISTS sensor_data(ts BIGINT, value REAL);
OK

SyncLite> INSERT INTO sensor_data VALUES(1714200000, 23.5);
OK  (1 row affected)

SyncLite> SELECT * FROM sensor_data;
ts            | value
--------------+-------
1714200000    | 23.5

SyncLite> exit
Bye.
```

All statements are captured in sync log files and eventually consolidated into the destination database by SyncLite Consolidator.

---

## 9. SyncLite Consolidator

**SyncLite Consolidator** is the central always-on sink that continuously reads log files and data streams produced by SyncLite Loggers, SyncLite DB instances, SyncLite DBReader, and SyncLite QReader, and consolidates all incoming data into one or more destination databases, data warehouses, or data lakes.

It is deployed as a Java WAR on Apache Tomcat and exposes a web UI for job configuration, monitoring, and live analytics.

```
SyncLite Logger  ─┐
SyncLite DB      ─┤
SyncLite DBReader ─┤──▶  Staging Storage  ──▶  SyncLite Consolidator  ──▶  Destination(s)
SyncLite QReader ─┘
```

### Key Features

- **Real-time, transactional replication** — processes CDC log files as they arrive; sub-second latency achievable on local stages.
- **Many-to-many consolidation** — one Consolidator job can aggregate data from thousands of edge devices simultaneously.
- **Multiple simultaneous destinations** — fan-out a single source stream into multiple destination databases in parallel.
- **Table / column / value filtering and mapping** — selectively replicate tables, rename columns, filter rows, and map data types.
- **Schema evolution** — handles DDL changes (new columns, new tables) propagated from edge devices.
- **Fine-tunable write modes** — `INSERT`, `UPSERT`, `REPLACE`, and append-only modes per table.
- **Database trigger installation** — automatically installs replication triggers on destination tables.
- **Built-in analytics UI** — query the destination database directly from the Consolidator web UI.
- **Live dashboard** — per-device replication lag, throughput, and error tracking.
- **Device command dispatch** — send commands back to edge devices through the staging layer.

### 9.1 Supported Destinations

| Category | Systems |
|---|---|
| Relational (OLTP) | PostgreSQL, MySQL, MariaDB, Microsoft SQL Server, Oracle, SQLite, DuckDB, Apache Derby, H2, HyperSQL |
| Data Warehouses | Snowflake, Google BigQuery, Amazon Redshift, ClickHouse |
| Data Lakes | Apache Iceberg, Delta Lake, Apache Hudi |
| NoSQL | MongoDB |
| File / Object Storage | Apache Parquet, CSV on S3 / MinIO / local file system |

### 9.2 Supported Staging Storages

SFTP · Amazon S3 · MinIO · Apache Kafka · Microsoft OneDrive · Google Drive · NFS · Local file system

### 9.3 Web UI

Open `http://localhost:8080/synclite-consolidator` after deployment.

| Page | Description |
|---|---|
| **Configure Job** | Wizard to set staging storage, destinations, table/column filtering rules, write mode |
| **Dashboard** | Live throughput, device count, replication lag |
| **List Devices** | Per-device drill-down: tables replicated, lag, errors |
| **Analyze Data** | In-browser SQL query panel against the destination DB |
| **Job Logs** | Full job and error logs |

Default Tomcat manager credentials: user `synclite` / password `synclite`

### 9.4 Consolidator Configuration

Key configuration options set through the web UI (stored internally by Consolidator):

| Setting | Description |
|---|---|
| **Staging storage type** | Local FS, SFTP, S3, MinIO, Kafka, OneDrive, Google Drive |
| **Staging directory / bucket** | Where to read device log files from |
| **Destination type** | PostgreSQL, MySQL, Snowflake, BigQuery, etc. |
| **Destination JDBC URL** | Connection string for the destination |
| **Write mode** | `INSERT` / `UPSERT` / `REPLACE` / `APPEND` per table |
| **Include / exclude tables** | Filter which tables to consolidate |
| **Column mappings** | Rename or skip columns at the destination |
| **Device encryption key** | Required if edge devices use `enable-encryption=true` |
| **Job statistics publishing** | Publish throughput metrics to an external monitoring system |

---

## 10. SyncLite DBReader

**SyncLite DBReader** is a web-based tool for setting up scalable, incremental, many-to-many database ETL, replication, and migration pipelines. It reads data from source databases and feeds the data into the SyncLite pipeline.

```
Source DB(s)  ──▶  SyncLite DBReader  ──▶  Staging Storage  ──▶  SyncLite Consolidator  ──▶  Destination(s)
```

### Key Features

- **Incremental / delta replication** — processes only changed rows since the last run using user-defined watermark columns or native CDC.
- **Log-based CDC** — captures changes at the binary log level for near-zero-latency replication where supported.
- **Many source → many destination** — one DBReader job can replicate from multiple source databases into multiple destinations simultaneously.
- **Schema inference** — automatically maps source schema to destination; supports custom overrides.
- **Table / column filtering** — include or exclude specific tables and columns.
- **Scheduling** — run on-demand or on a cron schedule via SyncLite Job Monitor.
- **Web UI** — full job configuration, progress tracking, and error monitoring from a browser.
- **Data migration** — one-time full-load migration with a single job configuration.

### 10.1 Supported Sources

| Category | Databases |
|---|---|
| Relational | PostgreSQL, MySQL, MariaDB, Microsoft SQL Server, Oracle Database, IBM DB2 |
| Embedded | SQLite, DuckDB, Apache Derby, H2, HyperSQL |
| Analytics | ClickHouse |
| Files | CSV files, Apache Parquet |

### 10.2 Replication Modes

| Mode | Description |
|---|---|
| **Full load** | One-time complete data migration |
| **Incremental (watermark)** | Reads only rows where a watermark column (e.g. `updated_at`) is greater than the last processed value |
| **Log-based CDC** | Reads the source database's binary/redo log for zero-impact, near-real-time replication |

### Quick Start

1. Deploy the SyncLite platform.
2. Open `http://localhost:8080/synclite-dbreader`.
3. Open `http://localhost:8080/synclite-consolidator` and configure a destination.
4. In DBReader, click **Configure Job**, fill in your source JDBC connection details, select tables, and start the job.
5. Monitor replication progress in the DBReader dashboard and destination data in the Consolidator UI.

---

## 11. SyncLite QReader (IoT MQTT Connector)

**SyncLite QReader** bridges MQTT message brokers with any database, data warehouse, or data lake supported by SyncLite Consolidator.

```
IoT Devices / Sensors
       │  MQTT publish
       ▼
  MQTT Broker(s)  ──subscribe──▶  SyncLite QReader  ──▶  Staging Storage  ──▶  SyncLite Consolidator  ──▶  Destination
```

### Key Features

- **Standard MQTT over Eclipse Paho** — works with any MQTT-compliant broker (v3.1).
- **One broker per job, unlimited topics** — subscribes to all topics via wildcard (`#`); run parallel jobs for multiple brokers.
- **CSV payload parsing** — parses comma-separated (or custom-delimited) message payloads.
- **Schema mapping** — maps MQTT topic paths and payload fields to destination table columns.
- **QoS levels** — supports QoS 0, 1, and 2.
- **TLS/SSL** — secure connections to brokers.
- **Auto-reconnect** — survives transient broker outages.
- **Web UI** — browser-based job configuration, live message rate gauges, and error logs.

### 11.1 Supported Brokers

| Broker | Notes |
|---|---|
| Eclipse Mosquitto | Popular open-source MQTT broker |
| EMQX | High-performance, scalable MQTT platform |
| HiveMQ | Enterprise MQTT broker |
| AWS IoT Core | Managed IoT broker (MQTT over TLS, port 8883) |
| Azure IoT Hub | Microsoft managed IoT broker (MQTT over TLS, port 8883) |
| Any MQTT v3.1-compliant broker | No broker-specific integration required |

### Use Cases

- **Industrial IoT:** machine sensor data → PostgreSQL / ClickHouse analytics
- **Smart building:** environmental sensors → time-series database
- **Fleet tracking:** GPS/telemetry → data warehouse
- **Energy monitoring:** smart meter readings → data lake

### Quick Start

1. Deploy the SyncLite platform.
2. Open `http://localhost:8080/synclite-qreader`.
3. Open `http://localhost:8080/synclite-consolidator` and configure a destination.
4. In QReader, click **Configure Job**: enter broker address, topic subscriptions, and field-to-column mappings.
5. Start the job and watch IoT data flow into your destination database in real time.

---

## 12. SyncLite Job Monitor

**SyncLite Job Monitor** is the operations hub for the SyncLite platform. It provides a unified web interface for managing, monitoring, scheduling, and controlling all SyncLite jobs running on a given host.

```
SyncLite Consolidator jobs  ─┐
SyncLite DBReader jobs       ├──▶  SyncLite Job Monitor  (web UI)
SyncLite QReader jobs       ─┘
```

### Key Features

- **Unified dashboard** — all running and stopped jobs across all SyncLite components in one view.
- **Job lifecycle control** — start, stop, restart, and configure individual jobs from the UI.
- **Scheduling** — cron-style schedules for batch ETL and migration jobs (DBReader, QReader).
- **Health monitoring** — real-time status indicators, error counts, and throughput metrics per job.
- **Alerting** — configure email or webhook notifications on job failure or lag threshold breaches.
- **Audit log** — full history of job state changes.
- **Multi-job support** — manage dozens of concurrent SyncLite jobs on a single host.

### Web UI

Open `http://localhost:8080/synclite-job-monitor` after deployment.

| Page | Description |
|---|---|
| **Dashboard** | All jobs — status, throughput, last run time |
| **Job Detail** | Logs, metrics, start / stop / configure controls |
| **Schedules** | Create and edit cron schedules for batch jobs |
| **Alerts** | Configure notification rules |

---

## 13. SyncLite Validator

**SyncLite Validator** is the end-to-end integration testing and data quality verification tool for SyncLite pipelines. It drives synthetic workloads through the full SyncLite pipeline and automatically validates that every row, every transaction, and every schema change arrived correctly and in the expected state.

```
Validator (workload generator)
       │  SQL operations via SyncLite Logger / SyncLite DB
       ▼
  Edge Device  ──▶  Staging Storage  ──▶  SyncLite Consolidator  ──▶  Destination DB
       │                                                                      │
       └──────────────── Validator (data comparison) ◀────────────────────────┘
```

### Key Features

- **Automated E2E verification** — generates a configurable workload, waits for consolidation, then compares source and destination row by row.
- **Multiple device types** — validates all SyncLite device types (SQLite, DuckDB, Derby, H2, HyperSQL, Streaming).
- **Schema evolution testing** — validates DDL changes (ALTER TABLE, new tables) propagate correctly.
- **Transaction integrity** — verifies committed vs. rolled-back transactions are reflected correctly at the destination.
- **Configurable workloads** — control table count, row count, update/delete ratios, and concurrency.
- **Detailed diff reports** — row-level mismatch reports with source vs. destination values.
- **Web UI** — configure test runs, view progress, and inspect results from a browser.

### Quick Start

1. Deploy the SyncLite platform and start a Consolidator job.
2. Open `http://localhost:8080/synclite-validator`.
3. Configure the validator: point it at the SyncLite Logger config and the destination DB connection.
4. Click **Run Validation**. The validator generates a workload, lets consolidation catch up, then compares all data automatically.
5. Review the pass/fail report and any row-level diffs.

---

## 14. Sample Web App

The **SyncLite Sample Web App** is a fully functional JSP/Servlet web application that demonstrates how to embed SyncLite Logger into a Java web application.

Open `http://localhost:8080/synclite-sample-app` after deployment.

### What It Demonstrates

| Feature | Description |
|---|---|
| **Device creation** | Create one or many SyncLite devices (SQLite, DuckDB, Derby, H2, HyperSQL, Streaming) from a web form |
| **SQL workload execution** | Run configurable INSERT / UPDATE / DELETE workloads on N devices in parallel |
| **Multi-device consolidation** | Watch hundreds of devices consolidating into a single destination DB |
| **Configuration** | Shows how to pass a `synclite_logger.conf` to `SyncLite.initialize()` |

### Architecture

```
Browser  ──HTTP──▶  SyncLite Sample Web App (Tomcat)
                         │  SyncLite Logger (embedded JDBC)
                         ▼
                   Edge Databases (SQLite / DuckDB / …)
                         │  sync log files
                         ▼
                   Local staging directory
                         │
                         ▼
                   SyncLite Consolidator  ──▶  Destination DB
```

Source entry points in `synclite-sample-web-app/web/src/`:
- `main/webapp/` — JSP views (create device, run workload, dashboard)
- `main/java/` — Servlet handlers and SyncLite Logger integration code
- `main/resources/synclite_logger.conf` — sample logger configuration

---

## 15. Staging Storage Setup

The staging storage is the intermediary layer between edge devices and SyncLite Consolidator. Configure `local-data-stage-directory` in `synclite_logger.conf` for local/NFS staging. For remote staging, configure the appropriate section and use the matching Docker helper scripts.

### Local / NFS

```properties
destination-type=FS
local-data-stage-directory=/path/to/shared/nfs/mount/stage
```

### SFTP

```properties
destination-type=SFTP
local-data-stage-directory=/path/to/local/buffer
sftp:host=sftp.example.com
sftp:port=22
sftp:user-name=synclite
sftp:password=changeme
sftp:remote-data-stage-directory=/upload/synclite-stage
```

Docker helper for a local SFTP staging server:

```bash
bin/stage/sftp/docker-deploy.sh
bin/stage/sftp/docker-start.sh
bin/stage/sftp/docker-stop.sh
```

### MinIO (S3-compatible object storage)

```properties
destination-type=MINIO
local-data-stage-directory=/path/to/local/buffer
minio:endpoint=http://localhost:9000
minio:access-key=minioadmin
minio:secret-key=minioadmin
minio:data-stage-bucket-name=synclite-data
minio:command-stage-bucket-name=synclite-commands
```

Docker helper for a local MinIO staging server:

```bash
bin/stage/minio/docker-deploy.sh
bin/stage/minio/docker-start.sh
bin/stage/minio/docker-stop.sh
```

### Amazon S3

```properties
destination-type=S3
local-data-stage-directory=/path/to/local/buffer
s3:access-key=AKIAIOSFODNN7EXAMPLE
s3:secret-key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
s3:data-stage-bucket-name=my-synclite-stage
s3:command-stage-bucket-name=my-synclite-commands
```

### Apache Kafka

```properties
destination-type=KAFKA
local-data-stage-directory=/path/to/local/buffer
kafka-producer:bootstrap.servers=broker1:9092,broker2:9092
kafka-consumer:bootstrap.servers=broker1:9092,broker2:9092
```

---

## 16. Docker Deployment

### All-in-one Docker (SyncLite platform)

```bash
# 1. Edit STAGE and DST variables at the top of docker-deploy.sh
#    to configure staging storage type and destination DB type.
cd bin/
./docker-deploy.sh    # Builds Docker image, deploys SyncLite container
./docker-start.sh     # Starts everything
./docker-stop.sh      # Stops everything
```

### Docker helpers for staging servers

```bash
# SFTP staging server
bin/stage/sftp/docker-deploy.sh
bin/stage/sftp/docker-start.sh

# MinIO object storage
bin/stage/minio/docker-deploy.sh
bin/stage/minio/docker-start.sh
```

### Docker helpers for destination databases

```bash
# PostgreSQL destination
bin/dst/postgresql/docker-deploy.sh
bin/dst/postgresql/docker-start.sh

# MySQL destination
bin/dst/mysql/docker-deploy.sh
bin/dst/mysql/docker-start.sh
```

> **Security warning:** The Docker helper scripts use default credentials. Always change usernames, passwords, and add TLS termination before production use.

---

## 17. Release Structure

```
synclite-platform-oss/
├── bin/
│   ├── deploy.sh / deploy.bat          # One-command setup: downloads Tomcat + JDK, deploys WARs
│   ├── start.sh / start.bat            # Start Tomcat + all SyncLite apps
│   ├── stop.sh / stop.bat              # Graceful shutdown
│   ├── docker-deploy.sh                # Docker image build + deploy
│   ├── docker-start.sh / docker-stop.sh
│   ├── tomcat-users.xml                # Default Tomcat user config (synclite/synclite)
│   ├── stage/
│   │   ├── sftp/                       # Docker scripts for SFTP staging server
│   │   └── minio/                      # Docker scripts for MinIO staging server
│   └── dst/
│       ├── postgresql/                 # Docker scripts for PostgreSQL destination
│       └── mysql/                      # Docker scripts for MySQL destination
│
├── lib/
│   ├── logger/
│   │   └── java/
│   │       └── synclite-logger-<version>.jar   # Add to your edge app classpath
│   └── consolidator/
│       └── synclite-consolidator-<version>.war
│
├── tools/
│   ├── synclite-client/                # CLI client (synclite-cli.sh / .bat)
│   ├── synclite-db/                    # SyncLite DB HTTP server
│   ├── synclite-dbreader/              # DBReader WAR + launcher
│   ├── synclite-qreader/               # QReader WAR + launcher
│   ├── synclite-job-monitor/           # Job Monitor WAR
│   └── synclite-validator/             # Validator WAR
│
└── sample-apps/
    ├── synclite-logger/
    │   ├── java/                       # Java sample apps
    │   │   ├── SyncliteDeviceApp.java
    │   │   ├── SyncLiteAppenderDeviceApp.java
    │   │   ├── SyncLiteStoreDeviceApp.java
    │   │   ├── SyncLiteStreamingApp.java
    │   │   ├── SyncLiteStoreAPIApp.java
    │   │   ├── SyncLiteStreamAPIApp.java
    │   │   ├── SyncLiteKafkaProduceApp.java
    │   │   └── SyncLiteJedisAPIApp.java
    │   ├── python/                     # Python sample apps (JayDeBeApi + JPype)
    │   │   ├── JayDeBeApi/             # SQL-style JDBC bridge samples
    │   │   └── JPype/                  # Direct Java API bridge samples
    │   └── jsp-servlet/                # Sample web app WAR
    └── synclite-db/
        └── (language SDK samples)
```

---

## 18. Security Considerations

- **Default credentials:** The default Tomcat credentials are `synclite` / `synclite`. Change them in `bin/tomcat-users.xml` before any network-exposed deployment.
- **Docker default credentials:** All Docker helper scripts use default usernames and passwords. Always change credentials and add TLS before production use.
- **Staging storage credentials:** SFTP passwords, S3/MinIO access keys, and Kafka credentials appear in `synclite_logger.conf`. Secure this file with appropriate file permissions and use secret management systems in production.
- **Device encryption:** Set `device-encryption-key-file` in `synclite_logger.conf` (pointing to a pre-existing DER public key file) to encrypt log files before shipping. Register the corresponding private key in the Consolidator job configuration. The file must exist at startup — the logger does not auto-generate it.
- **Network exposure:** SyncLite DB's HTTP server has no TLS built in — place it behind a reverse proxy with TLS in production.
- **Authentication:** Always configure Bearer token or HMAC app-auth for SyncLite DB in any environment accessible over a network.

---

## 19. Patent & License

**License:** SyncLite is licensed under the [Apache License 2.0](LICENSE).

**Patent:** SyncLite is backed by patented technology. More info: https://www.synclite.io/resources/patent

---

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening a pull request.

---

## Resources

| Resource | Link |
|---|---|
| Website | https://www.synclite.io |
| Full Online Documentation | https://www.synclite.io/resources/documentation |
| Smart Database ETL solution | https://www.synclite.io/solutions/smart-database-etl |
| IoT Data Connector solution | https://www.synclite.io/solutions/iot-data-connector |
| Patent | https://www.synclite.io/resources/patent |
| Community Slack | https://join.slack.com/t/syncliteworkspace/shared_invite/zt-2pz945vva-uuKapsubC9Mu~uYDRKo6Jw |
