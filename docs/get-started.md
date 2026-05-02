# Getting Started with SyncLite

> **Build Anything, Sync Anywhere** — open-source, low-code relational data synchronization and consolidation platform.
>
> Full interactive guide: https://www.synclite.io/resources/get-started  
> Full documentation: https://www.synclite.io/resources/documentation

---

## What Is SyncLite?

SyncLite gives developers a single toolkit to:

- Build **offline-first, sync-ready edge and desktop applications** using embedded databases (SQLite, DuckDB, Apache Derby, H2, HyperSQL) that automatically replicate changes to any cloud destination.
- Stand up **last-mile data streaming pipelines** with high-throughput event ingestion delivered into any database, data warehouse, or data lake.
- Configure **database ETL, replication, and migration** pipelines across heterogeneous systems with minimal code.
- Connect **IoT / MQTT message brokers** to analytical databases in minutes.

All flows follow one unified architecture:

```
Edge Sources (SyncLite Logger / DB / DBReader / QReader)
     │
     ▼  compact binary log files
  Staging Storage  (local dir / SFTP / S3 / MinIO / Kafka / OneDrive / Google Drive)
     │
     ▼
  SyncLite Consolidator  (always-on sink)
     │
     ▼
  Destination DB / Data Warehouse / Data Lake
```

---

## Platform Components

| Component | What It Does |
|---|---|
| **SyncLite Logger** | Embeddable JDBC driver for Java/Python edge apps — wraps SQLite, DuckDB, Derby, H2, HyperSQL |
| **SyncLite DB** | Standalone HTTP/JSON database server for any language |
| **SyncLite Client** | Interactive CLI for managing SyncLite devices |
| **SyncLite Consolidator** | Central real-time consolidation engine — delivers data to destinations |
| **SyncLite DBReader** | Database ETL / replication / migration tool |
| **SyncLite QReader** | IoT MQTT connector (Eclipse Paho; works with any MQTT v3.1 broker) |
| **SyncLite Job Monitor** | Unified job management and scheduling UI |
| **SyncLite Validator** | End-to-end integration testing |
| **Sample Web App** | JSP/Servlet demo showing SyncLite Logger in action |

---

## Prerequisites

| Requirement | Version |
|---|---|
| Java | 25 |
| Apache Maven | 3.8.6+ |
| Git | any recent version |

> The `deploy.sh` / `deploy.bat` scripts download **Apache Tomcat 9.0.117** and **OpenJDK 25** automatically — no manual JDK installation required for a quick start.

---

## Step 1 — Clone and Build

```bash
git clone --recurse-submodules git@github.com:syncliteio/SyncLite.git SyncLite
cd SyncLite
mvn -Drevision=oss clean install
```

The full platform release is assembled under:

```
SyncLite/target/synclite-platform-oss/
├── bin/          # deploy / start / stop scripts, Docker helpers
├── lib/          # synclite-logger JAR, consolidator WAR
├── tools/        # synclite-db, dbreader, qreader, job-monitor, validator
└── sample-apps/  # Java, Python, and JSP/Servlet samples
```

---

## Step 2 — Deploy and Start

### Native (Windows / Linux / macOS)

```bash
cd target/synclite-platform-oss/bin/

# First run: downloads Tomcat + JDK, deploys all WARs
./deploy.sh          # Linux/macOS
deploy.bat           # Windows

# Start Tomcat and all SyncLite apps
./start.sh           # Linux/macOS
start.bat            # Windows
```

### Docker (all-in-one)

```bash
cd target/synclite-platform-oss/bin/

# Edit STAGE and DST variables at the top of docker-deploy.sh first
./docker-deploy.sh   # Builds image + starts containers
./docker-start.sh    # Start containers
./docker-stop.sh     # Stop containers
```

Docker staging and destination helpers are also available:

```bash
bin/stage/sftp/docker-deploy.sh     # SFTP staging server
bin/stage/minio/docker-deploy.sh    # MinIO object storage
bin/dst/postgresql/docker-deploy.sh # PostgreSQL destination
bin/dst/mysql/docker-deploy.sh      # MySQL destination
```

> ⚠️ Docker helper scripts use default credentials. Change usernames, passwords, and enable TLS before any production use.

### App URLs (after start)

| URL | App |
|---|---|
| http://localhost:8080/synclite-consolidator | Configure and monitor consolidation jobs |
| http://localhost:8080/synclite-sample-app | Create devices, run SQL workloads, see live sync |
| http://localhost:8080/synclite-dbreader | Set up database ETL/replication pipelines |
| http://localhost:8080/synclite-qreader | Set up IoT MQTT connector pipelines |
| http://localhost:8080/synclite-job-monitor | Manage and schedule all SyncLite jobs |
| http://localhost:8080/manager | Tomcat manager (`synclite` / `synclite`) |

---

## Step 3 — Choose Your Use Case

### A. Edge / Desktop App with Embedded Database (Java)

Add `synclite-logger-<version>.jar` to your classpath, then:

```java
import io.synclite.logger.*;
import java.nio.file.Path;
import java.sql.*;

Path dbDir  = Path.of(System.getProperty("user.home"), "synclite", "db");
Path dbPath = dbDir.resolve("myapp.db");
Path conf   = dbDir.resolve("synclite_logger.conf");

// Initialize with SQLite (replace SQLite / synclite_sqlite with DuckDB, Derby, H2, HyperSQL as needed)
Class.forName("io.synclite.logger.SQLite");
SQLite.initialize(dbPath, conf);

try (Connection conn = DriverManager.getConnection("jdbc:synclite_sqlite:" + dbPath);
     Statement  stmt = conn.createStatement()) {

    stmt.execute("CREATE TABLE IF NOT EXISTS orders(id INT, item TEXT, qty INT)");
    stmt.execute("INSERT INTO orders VALUES(1, 'widget', 100)");
    // ↑ captured in a log file and shipped to staging storage automatically
}

SQLite.closeAll();
```

**Supported embedded databases via Logger:**

| Class / JDBC prefix | Engine |
|---|---|
| `SQLite` / `synclite_sqlite` | SQLite |
| `DuckDB` / `synclite_duckdb` | DuckDB |
| `Derby` / `synclite_derby` | Apache Derby |
| `H2` / `synclite_h2` | H2 |
| `HyperSQL` / `synclite_hsqldb` | HyperSQL |

---

### B. SyncLiteStore API — CRUD without Raw SQL

`STORE` device types (`SQLITE_STORE`, `DUCKDB_STORE`, etc.) expose the `SyncLiteStore` API: typed `insert`, `update`, `delete`, and `selectAll` methods that handle schema evolution automatically and log every operation to the replication pipeline.

```java
import io.synclite.logger.SQLiteStore;
import io.synclite.logger.SyncLiteStore;

Class.forName("io.synclite.logger.SQLiteStore");
SQLiteStore.initialize(dbPath, conf);

try (SyncLiteStore store = SQLiteStore.open(dbPath)) {
    store.createTable("orders", new LinkedHashMap<>(Map.of(
        "id",   "INTEGER PRIMARY KEY",
        "item", "TEXT",
        "qty",  "INTEGER"
    )));
    store.insert("orders", Map.of("id", 1, "item", "widget", "qty", 100));
    store.update("orders", Map.of("qty", 150), Map.of("id", 1));
    store.delete("orders", Map.of("id", 1));
    List<Map<String, Object>> rows = store.selectAll("orders");
}

SQLiteStore.closeDevice(dbPath);
```

---

### C. SyncLiteStream API — Append-Only Event Ingestion

`SyncLiteStream` wraps the `STREAMING` device with a fluent `insert` / `insertBatch` API. UPDATE and DELETE are absent by design — this models event flow, not mutable records.

```java
import io.synclite.logger.Streaming;
import io.synclite.logger.SyncLiteStream;

Class.forName("io.synclite.logger.Streaming");
Streaming.initialize(dbPath, conf);

try (SyncLiteStream stream = SyncLiteStream.open(dbPath)) {
    stream.createTable("events", new LinkedHashMap<>(Map.of(
        "ts",         "BIGINT",
        "event_type", "TEXT",
        "user_id",    "TEXT"
    )));
    stream.insert("events", Map.of(
        "ts", System.currentTimeMillis(), "event_type", "SIGNUP", "user_id", "u1"
    ));
    stream.insertBatch("events", List.of(
        Map.of("ts", System.currentTimeMillis(), "event_type", "VIEW",     "user_id", "u2"),
        Map.of("ts", System.currentTimeMillis(), "event_type", "PURCHASE", "user_id", "u3")
    ));
}
```

---

### D. SyncLite DB — Any Language via HTTP/JSON

Start the server, then send plain HTTP POST requests — no SDK needed.

```bash
# Start
./tools/synclite-db/synclite-db.sh --config synclite_db.conf   # Linux/macOS
tools\synclite-db\synclite-db.bat --config synclite_db.conf    # Windows
```

**Python example:**

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

# DDL
requests.post(BASE, json={
    "db-path": "/tmp/myapp.db",
    "sql": "CREATE TABLE IF NOT EXISTS events(id INT, payload TEXT)"
})

# Batched insert
requests.post(BASE, json={
    "db-path": "/tmp/myapp.db",
    "sql": "INSERT INTO events VALUES(?, ?)",
    "arguments": [[1, "hello"], [2, "world"]]
})
```

SDK samples for Java, Python, C#, C++, Go, Rust, Ruby, and Node.js are in [`synclite-db/sdk-source/`](synclite-db/sdk-source/).

---

### E. Database ETL / Replication with DBReader

DBReader connects to an existing database and feeds incremental changes into the SyncLite pipeline.

1. Open http://localhost:8080/synclite-dbreader
2. Open http://localhost:8080/synclite-consolidator and configure a destination.
3. In DBReader click **Configure Job** → enter source JDBC connection details, select tables, choose `INCREMENTAL` or `CDC` mode, and start.

**Supported source databases:** PostgreSQL, MySQL, MariaDB, Microsoft SQL Server, Oracle, IBM DB2, SQLite, DuckDB, Apache Derby, H2, HyperSQL, ClickHouse, CSV, Apache Parquet.

---

### F. IoT / MQTT Ingestion with QReader

QReader subscribes to MQTT topics and lands data in your destination database in real time using the Eclipse Paho MQTT client — any MQTT v3.1 broker works.

1. Open http://localhost:8080/synclite-qreader
2. Open http://localhost:8080/synclite-consolidator and configure a destination.
3. In QReader click **Configure Job** → enter broker URL, topic subscriptions, QoS level, and field-to-column mappings, then start.

**Tested brokers:** Eclipse Mosquitto, EMQX, HiveMQ, AWS IoT Core, Azure IoT Hub.

---

## Step 4 — Configure the Consolidator

Open **http://localhost:8080/synclite-consolidator** and:

1. **Configure Job** — set the staging storage path (or SFTP/S3/MinIO/Kafka URL).
2. Add a **Destination** — choose from PostgreSQL, MySQL, MariaDB, SQL Server, Oracle, Snowflake, BigQuery, Redshift, ClickHouse, MongoDB, Apache Iceberg, Delta Lake, Apache Hudi, Parquet/CSV.
3. Start the job. The dashboard shows per-device replication lag, throughput, and errors in real time.

---

## Step 5 — Staging Storage Options

Configure `local-data-stage-directory` in `synclite_logger.conf` for local or NFS staging.  
For remote staging, set the appropriate properties in the same config file:

| Staging Backend | Docker helper |
|---|---|
| SFTP | `bin/stage/sftp/docker-deploy.sh` |
| MinIO | `bin/stage/minio/docker-deploy.sh` |
| Amazon S3 | configure `s3-*` properties in conf |
| Apache Kafka | configure `kafka-*` properties in conf |
| Microsoft OneDrive | configure `onedrive-*` properties in conf |
| Google Drive | configure `gdrive-*` properties in conf |

---

## Destinations Supported

| Category | Systems |
|---|---|
| Relational (OLTP) | PostgreSQL, MySQL, MariaDB, Microsoft SQL Server, Oracle, SQLite, DuckDB, Derby, H2, HyperSQL |
| Data Warehouses | Snowflake, Google BigQuery, Amazon Redshift, ClickHouse |
| Data Lakes | Apache Iceberg, Delta Lake, Apache Hudi |
| NoSQL | MongoDB |
| File / Object | Apache Parquet, CSV |

---

## What's Next?

| Resource | Link |
|---|---|
| Interactive Get Started guide | https://www.synclite.io/resources/get-started |
| Full platform documentation | https://www.synclite.io/resources/documentation |
| Website | https://www.synclite.io |
| GitHub repository | https://github.com/syncliteio/SyncLite |
| Support email | support@synclite.io |
| Patent | about.html#patent |
| Contribution guide | [CONTRIBUTING.md](CONTRIBUTING.md) |
| License (Apache 2.0) | [LICENSE](LICENSE) |

---

← Back to the [platform README](README.md)
