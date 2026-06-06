# Getting Started with SyncLite

> **Build Anything, Sync Anywhere** — open-source, low-code relational data synchronization and consolidation platform.
>
> Full interactive guide: https://www.synclite.io/resources/get-started  
> Full documentation: https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md

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
      v  compact binary log files
  Staging Storage  (local dir / SFTP / S3 / MinIO / Kafka / OneDrive / Google Drive)
     │
      v
  SyncLite Consolidator  (always-on sink)
     │
      v
  Destination DB / Data Warehouse / Data Lake
```

---

## Platform Components

| Component | What It Does |
|---|---|
| **SyncLite Logger** | Embeddable JDBC driver for Java edge apps — wraps SQLite, DuckDB, Derby, H2, HyperSQL |
| **SyncLite Runtime** | Full SyncLite runtime in Rust (logger + consolidator), consumable from Rust, Python, and C++ |
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
├─ bin/          # deploy / start / stop scripts, Docker helpers
├─ lib/          # synclite-logger JAR, consolidator WAR
├─ tools/        # synclite-db, dbreader, qreader, job-monitor, validator
└─ sample-apps/  # Java, Python, and JSP/Servlet samples
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
./docker-deploy.sh   # Builds synclite-platform image + starts containers
./docker-start.sh    # Start synclite-platform container (+ optional helpers)
./docker-stop.sh     # Stop synclite-platform container (+ optional helpers)
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

### 🦀 Rust — Pure Native Library (NEW)

The entire SyncLite runtime is now packaged as a single embeddable Rust
crate, [`synclite`](https://github.com/syncliteio/SyncLite/tree/main/synclite-logger-rust).
No JVM, no JAR — just `cargo add synclite` and ship a single binary.

The crate embeds the `synclitecdc` native CDC helper (extracted on first
use) so SQL devices work out of the box for Linux x86_64/x86 and
Windows x86_64/x86.

```rust
use synclite::rusqlite::Connection;
use synclite::{DestinationOptions, DeviceType, DstSyncMode, DstType, Result, SyncLiteOptions, Value};
use postgres::{Client, NoTls};

fn main() -> Result<()> {
    const DB_PATH: &str = "orders.db";
    const DEVICE_NAME: &str = "orders-device";

    // Wire up logger + shipper + embedded consolidator in one call.
    synclite::initialize(
        DeviceType::Sqlite,
        DEVICE_NAME,
        DB_PATH,
        Some(DestinationOptions {
            dst_type: DstType::Postgres,
            dst_connection_string:
                "postgresql://postgres:postgres@localhost:5432/syncdb".into(),
            dst_database: Some("syncdb".into()),
            dst_schema:   Some("syncschema".into()),
            dst_sync_mode: DstSyncMode::Consolidation,
        }),
        SyncLiteOptions::default(),
    )?;

    let mut conn = Connection::open(DB_PATH)?;
    conn.execute("CREATE TABLE IF NOT EXISTS orders(id INTEGER, item TEXT, qty INTEGER)", &[])?;
    conn.execute(
        "INSERT INTO orders VALUES(?, ?, ?)",
        &[Value::Int(1), Value::Text("widget".into()), Value::Int(100)],
    )?;
    conn.commit()?;

    // Read back from local SQLite before forcing sync.
    let local_rows = conn.query("SELECT id, item, qty FROM orders WHERE id = 1", &[])?;
    if let Some(row) = local_rows.first() {
        println!("[READ FROM LOCAL DB] {:?}", row);
    }

    // Roll the active log segment + wait for PostgreSQL apply.
    conn.flush()?;
    match synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30)) {
        Ok(()) => {
            println!("[SYNC] await_sync succeeded");
            let mut pg = Client::connect(
                "postgresql://postgres:postgres@localhost:5432/syncdb",
                NoTls,
            )?;
            let pg_row = pg.query_opt(
                "SELECT row_to_json(t)::text FROM (SELECT * FROM syncschema.orders WHERE id = $1) t",
                &[&1_i64],
            )?;
            println!("[READ FROM POSTGRESQL POST SYNC] {:?}", pg_row);
        }
        Err(e) => println!("[SYNC] await_sync failed: {e}"),
    }
    conn.close()?;
    Ok(())
}
```

**Supported devices:** `Sqlite` (SQL + STORE + STREAMING), `Duckdb` (SQL + STORE).
**Supported destinations:** `Sqlite`, `Duckdb`, `Postgres`.

Runnable samples live under `synclite-code-samples/synclite-logger/rust/` —
`cargo run --example synclite_rusqlite` from that folder gets you the
rusqlite-style example, with `synclite_duckdb_store` and
`synclite_streaming` covering the other device shapes.

---

### A. Edge / Desktop App with Embedded Database (Java)

Add `synclite-<version>.jar` to your classpath, then:

```java
import io.synclite.logger.*;
import java.nio.file.Path;
import java.sql.*;

Path dbDir  = Path.of(System.getProperty("user.home"), "synclite", "db");
Path dbPath = dbDir.resolve("myapp.db");
Path conf   = dbDir.resolve("synclite.conf");

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
    "db-name": "myapp",
    "synclite-logger-options": {
        "local-data-stage-directory": "/tmp/synclite/stageDir",
        "device-stage-type": "FS"
    },
    "sql": "initialize"
})

# DDL
requests.post(BASE, json={
    "db-name": "myapp",
    "sql": "CREATE TABLE IF NOT EXISTS events(id INT, payload TEXT)"
})

# Batched insert
requests.post(BASE, json={
    "db-name": "myapp",
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
2. Add a **Destination** — choose from PostgreSQL, MySQL, MariaDB, SQL Server, Oracle, Amazon Redshift, ClickHouse, MongoDB, Apache Iceberg, Delta Lake, Apache Hudi, Parquet/CSV.
3. Start the job. The dashboard shows per-device replication lag, throughput, and errors in real time.

---

## Step 5 — Staging Storage Options

Configure `local-data-stage-directory` in `synclite.conf` for local or NFS staging.  
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
| Data Warehouses | Amazon Redshift, ClickHouse |
| Data Lakes | Apache Iceberg, Delta Lake, Apache Hudi |
| NoSQL | MongoDB |
| File / Object | Apache Parquet, CSV |

---

## What's Next?

| Resource | Link |
|---|---|
| Interactive Get Started guide | https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md#getting-started |
| Full platform documentation | https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md |
| Website | https://github.com/syncliteio/SyncLite |
| GitHub repository | https://github.com/syncliteio/SyncLite |
| Support email | support@synclite.io |
| Patent | about.html#patent |
| Contribution guide | [CONTRIBUTING.md](CONTRIBUTING.md) |
| License (Apache 2.0) | [LICENSE](LICENSE) |

---

← Back to the [platform README](README.md)
