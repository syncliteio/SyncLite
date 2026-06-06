
<p align="center">
  <a href="https://www.synclite.io">
  <img src="docs/images/SyncLite_logo.png" alt="SyncLite - Build Anything Sync Anywhere">
  </a>
  <p align="center">
    <a href="https://www.synclite.io">Website</a>
    ·
    <a href="https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md">Documentation</a>
    ·
  </p>
</p>

# SyncLite — Build Anything, Sync Anywhere

**SyncLite** is an open-source, low-code relational data synchronization and consolidation platform. It gives developers a single, coherent toolkit to:

- Build **offline-first, sync-ready edge and desktop applications** using embedded databases (SQLite, DuckDB, Apache Derby, H2, HyperSQL) that automatically replicate their data to any cloud destination.
- Stand up **last-mile data streaming pipelines** that ingest at massive scale and deliver into any database, data warehouse, or data lake.
- Configure **database ETL, replication, and migration** pipelines across heterogeneous systems with minimal code.
- Connect **IoT message brokers** to analytical databases in minutes.

All of this flows through a unified pipeline architecture: sources produce compact binary log files → files are shipped to staging storage → SyncLite Consolidator delivers them to one or more destinations in real time.

<p align="center">
  <a href="https://www.synclite.io">
  <img src="docs/images/SyncLite_Overview.png" width="80%" height="80%" alt="SyncLite - Build Anything Sync Anywhere">
  </a>
</p>

---


## Why SyncLite?

Most data integration problems at the edge are solved today by one of two approaches: ship everything to the cloud and query there (high latency, no offline resilience), or write custom replication code (brittle, expensive, operationally painful). SyncLite is a third way.

---

## Components

| Component | Description | README |
|---|---|---|
| **SyncLite Logger** | Embeddable JDBC driver for Java edge apps | [→](https://github.com/syncliteio/synclite-logger-java/blob/main/README.md) |
| **SyncLite Runtime** | Full SyncLite runtime in Rust (logger + consolidator), consumable from Rust, Python, and C++ | [→](https://github.com/syncliteio/SyncLite/tree/main/synclite-logger-rust) |
| **SyncLite DB** | Local-first, sync-enabled database server. Optimized for localhost/edge, exposes embedded DBs over HTTP/JSON for any language. | [→](https://github.com/syncliteio/synclite-db/blob/main/README.md) |
| **SyncLite Client** | Interactive CLI for SyncLite devices | [→](https://github.com/syncliteio/synclite-client/blob/main/README.md) |
| **SyncLite Consolidator** | Central real-time consolidation engine | [→](https://github.com/syncliteio/synclite-consolidator/blob/main/README.md) |
| **SyncLite DBReader** | Database ETL / replication / migration tool | [→](https://github.com/syncliteio/synclite-dbreader/blob/main/README.md) |
| **SyncLite QReader** | IoT MQTT connector | [→](https://github.com/syncliteio/synclite-qreader/blob/main/README.md) |
| **SyncLite Job Monitor** | Unified job management and scheduling UI | [→](https://github.com/syncliteio/synclite-job-monitor/blob/main/README.md) |
| **SyncLite Validator** | End-to-end integration testing tool | [→](https://github.com/syncliteio/synclite-validator/blob/main/README.md) |
| **Sample Web App** | JSP/Servlet demo showing SyncLite Logger in action | [→](https://github.com/syncliteio/synclite-sample-web-app/blob/main/README.md) |


## SyncLite Devices

When we talk about SyncLite "devices" there are three high-level device categories you should expect across the product documentation and examples:

- **SQL Devices:** Full SQL-compatible embedded database devices (SQLite, DuckDB, Apache Derby, H2, HyperSQL). These devices expose the full SQL surface (CREATE/ALTER/SELECT/INSERT/UPDATE/DELETE) and are ideal when applications must run arbitrary SQL locally. Replication for SQL devices relies on SyncLite capturing SQL/command logs which are later processed by the Consolidator to generate CDC-style records for destinations.

- **Store Devices:** Lightweight CRUD-oriented devices (SQLite_STORE, DUCKDB_STORE, DERBY_STORE, H2_STORE, HYPERSQL_STORE) that expose the `SyncLiteStore` API (typed `insert` / `update` / `delete` / `selectAll`) rather than a raw SQL surface. Store devices:
    - Provide a simpler, typed CRUD API that automatically handles schema evolution (auto-add columns) and reduces application boilerplate.
    - Produce logs that are applied directly to destinations by the Consolidator — they do not require a separate two-step deduce-and-apply flow used for general SQL devices.
    - Are ideal when your application needs stable CRUD semantics, lower cognitive overhead, and deterministic replication to destinations.

- **Streaming Device:** The `STREAMING` device models append-only ingestion and exposes `SyncLiteStream` semantics (fluent `insert` / `insertBatch`). It is optimized for high-throughput event capture where UPDATE/DELETE semantics are not required.

Notes:
- Appender and DBLogger device types exist internally but are intentionally left undocumented in user-facing docs and examples.
- When reading the docs, prefer the three-category mental model above — it simplifies architecture discussions and helps choose the right device for your workload.


---

## Build SyncLite

**Prerequisites (Java-only build):** Java 25, Apache Maven 3.8.6+

**Additional prerequisites (build all loggers including Rust):**
- Rust toolchain 1.86.0
- Cargo 1.86.0 (bundled with Rust 1.86.0)
- [`cargo-zigbuild`](https://github.com/rust-cross/cargo-zigbuild) and the [Zig](https://ziglang.org/download/) compiler on `PATH`
- Rust standard libraries for Linux x86_64 and aarch64

The Rust cdylibs for **Linux x86_64 and aarch64** are cross-compiled on every
host so a single `mvn package` produces a complete, multi-arch `lib/native/`
payload. Install the cross-compile toolchain once on the build host:

```bash
cargo install cargo-zigbuild
winget install zig.zig
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-gnu
rustup target add x86_64-unknown-linux-musl
rustup target add aarch64-unknown-linux-musl
# zig must be on PATH — download from https://ziglang.org/download/
```

> If `mvn package` fails with `error: no such command: zigbuild`, you are
> missing `cargo-zigbuild` — run `cargo install cargo-zigbuild` and retry.

macOS (`libsynclite_<rev>.dylib`) still requires running the build on a
macOS host — the Apple SDK isn't redistributable so it cannot be
cross-compiled from Windows or Linux.

```bash
git clone --recurse-submodules https://github.com/syncliteio/SyncLite.git SyncLite
cd SyncLite
```

Build all components (including non-Java loggers):

```bash
mvn -Drevision=oss clean install
```

Build Java components only (skip non-Java logger build and packaging):

```bash
mvn -Drevision=oss -DskipNonJavaLoggers=true clean install
```

The release is assembled under `SyncLite/target/synclite-platform-oss/`.

> The `bin/deploy.sh` / `bin/deploy.bat` scripts download Apache Tomcat 9.0.117 and OpenJDK 25 automatically. No manual installation needed for a quick start.

## Release Structure

```
synclite-platform-oss/
├─ bin/
│   ├─ deploy.sh / deploy.bat        # One-command setup: downloads Tomcat + JDK, deploys WARs
│   ├─ start.sh / start.bat          # Start Tomcat + all SyncLite apps
│   ├─ stop.sh / stop.bat            # Graceful shutdown
│   ├─ docker-deploy.sh              # Docker image build + deploy
│   ├─ docker-start.sh / docker-stop.sh
│   ├─ stage/sftp/                   # Docker scripts for SFTP staging server
│   ├─ stage/minio/                  # Docker scripts for MinIO staging server
│   ├─ dst/postgresql/               # Docker scripts for PostgreSQL destination
│   └─ dst/mysql/                    # Docker scripts for MySQL destination
│
├─ lib/
│   ├─ java/
│   │   ├─ synclite-<version>.jar     # Add to your edge app classpath
│   │   └─ synclite.conf
│   └─ rust/                                        # Multi-arch native cdylibs
│       ├─ libsynclite_<version>.dll                 # Windows host build
│       ├─ libsynclite_<version>.lib                 # Windows import library
│       ├─ libsynclite_<version>_linux_x86_64.so     # cross-compiled
│       ├─ libsynclite_<version>_linux_aarch64.so    # cross-compiled
│       ├─ libsynclite_<version>.dylib               # only if built on macOS
│       └─ synclite.conf
│
├─ tools/
│   ├─ synclite-consolidator/        # Consolidator WAR + runtime config
│   ├─ synclite-client/              # CLI client
│   ├─ synclite-db/                  # SyncLite DB server
│   ├─ synclite-dbreader/            # DBReader WAR + launcher
│   ├─ synclite-qreader/             # QReader WAR + launcher
│   ├─ synclite-job-monitor/         # Job Monitor WAR
│   └─ synclite-validator/           # Validator WAR
│
└─ sample-apps/
    ├─ synclite-logger/java/         # Java sample apps
    ├─ synclite-logger/python/       # Python sample apps
    └─ synclite-logger/jsp-servlet/  # Sample web app WAR
```

---

## Quick Start (5 minutes)

### Native (Windows / Ubuntu)

```bash
cd bin/
./deploy.sh      # or deploy.bat on Windows
./start.sh       # or start.bat on Windows
```

| URL | App |
|---|---|
| http://localhost:8080/synclite-consolidator | Configure and monitor consolidation jobs |
| http://localhost:8080/synclite-sample-app | Create devices, run SQL workloads, see live sync |
| http://localhost:8080/synclite-dbreader | Set up database ETL/replication pipelines |
| http://localhost:8080/synclite-qreader | Set up IoT MQTT connector pipelines |
| http://localhost:8080/synclite-job-monitor | Manage and schedule all SyncLite jobs |
| http://localhost:8080/manager | Tomcat manager (user: `synclite` / pwd: `synclite`) |

### Docker (all-in-one)

```bash
# Edit STAGE and DST at the top of docker-deploy.sh, then:
cd bin/
./docker-deploy.sh     # Builds synclite-platform image (+ optional SFTP/MinIO + PostgreSQL/MySQL)
./docker-start.sh      # Starts synclite-platform container and optional helpers
./docker-stop.sh       # Stops synclite-platform container and optional helpers
```

---

## Using SyncLite Logger (Java)

Add `synclite-<version>.jar` to your project, then:

```java
import io.synclite.logger.*;
import java.nio.file.Path;
import java.sql.*;

Path dbDir  = Path.of(System.getProperty("user.home"), "synclite", "db");
Path dbPath = dbDir.resolve("myapp.db");
Path conf   = dbDir.resolve("synclite.conf");

Class.forName("io.synclite.logger.SQLite");
SQLite.initialize(dbPath, conf);

try (Connection c = DriverManager.getConnection("jdbc:synclite_sqlite:" + dbPath);
     Statement  s = c.createStatement()) {
    s.execute("CREATE TABLE IF NOT EXISTS orders(id INT, item TEXT, qty INT)");
    s.execute("INSERT INTO orders VALUES(1, 'widget', 100)");
    // ↑ captured in a log file and shipped to staging storage automatically
}
SQLite.closeAll();
```

For other embedded databases replace `SQLite` / `synclite_sqlite` with `DuckDB` / `synclite_duckdb`, `Derby` / `synclite_derby`, `H2` / `synclite_h2`, or `HyperSQL` / `synclite_hsqldb`.

Full configuration reference: `lib/logger/synclite.conf` · [Documentation](https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md)

### SyncLiteStore API — CRUD without raw SQL

**STORE device types** (`SQLITE_STORE`, `DUCKDB_STORE`, `DERBY_STORE`, `H2_STORE`, `HYPERSQL_STORE`) expose the `SyncLiteStore` API: typed `insert` / `update` / `delete` / `selectAll` methods that handle schema evolution automatically and log every operation to the replication pipeline.

```java
import io.synclite.logger.SQLiteStore;
import io.synclite.logger.SyncLiteStore;

Class.forName("io.synclite.logger.SQLiteStore");
SQLiteStore.initialize(dbPath, conf);

try (SyncLiteStore store = SQLiteStore.open(dbPath)) {
    store.createTable("orders", new LinkedHashMap<>(Map.of(
        "id",  "INTEGER PRIMARY KEY",
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

### SyncLiteStream API — Fluent Append-Only Ingestion

`SyncLiteStream` wraps the `STREAMING` device with a fluent `insert` / `insertBatch` API. UPDATE and DELETE are intentionally absent — this API models event flow, not mutable records.

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
    stream.insert("events", Map.of("ts", System.currentTimeMillis(), "event_type", "SIGNUP", "user_id", "u1"));
    stream.insertBatch("events", List.of(
        Map.of("ts", System.currentTimeMillis(), "event_type", "VIEW",     "user_id", "u2", "source", "web"),
        Map.of("ts", System.currentTimeMillis(), "event_type", "PURCHASE", "user_id", "u3", "source", "app")
    ));
}
```

### Jedis (Redis-Compatible) API

`io.synclite.logger.Jedis` is a drop-in subclass of `redis.clients.jedis.Jedis`. Every write is durably committed to a `SQLITE_STORE` device before being forwarded to Redis, and the cache is repopulated from the store on restart.

```java
import io.synclite.logger.Jedis;

// Managed mode — Jedis handles SQLiteStore initialise / open / close
try (Jedis jedis = Jedis.builder(dbPath, conf, "cache-device")
        .host("localhost").port(6379).build()) {
    jedis.set("user:1:name", "Alice");
    jedis.hset("session:42", Map.of("token", "abc123", "status", "active"));
    jedis.rpush("queue", "job-1", "job-2");
    jedis.sadd("tags", "etl", "cdc");
    jedis.zadd("leaderboard", Map.of("Alice", 100.0, "Bob", 200.0));
    jedis.del("tmp");
}
```

Alternatively, supply a pre-opened `SyncLiteStore` via `Jedis.builder(store)` when managing the store lifecycle externally.

---

## Using SyncLite DB (any language)

```bash
# Start the server
cd tools/synclite-db
./synclite-db.sh --config synclite_db.conf
```

```python
# Python client (plain HTTP — no SDK needed)
import requests, json

BASE = "http://localhost:5555/synclite"

requests.post(BASE, json={"db-type": "SQLITE", "db-name": "myapp",
    "synclite-logger-options": {"local-data-stage-directory": "/tmp/stage"},
    "sql": "initialize"})

requests.post(BASE, json={"db-name": "myapp",
    "sql": "CREATE TABLE IF NOT EXISTS t1(a INT, b TEXT)"})

requests.post(BASE, json={"db-name": "myapp",
    "sql": "INSERT INTO t1 VALUES(?, ?)", "arguments": [[1, "hello"], [2, "world"]]})
```

SDK samples for Java, Python, C#, C++, Go, Rust, Ruby, Node.js: [synclite-db/sdk-source/](synclite-db/sdk-source/)

---

## Staging Storage Setup

Configure `local-data-stage-directory` in `synclite.conf` for local/NFS staging. For remote staging (SFTP, S3, MinIO, Kafka, OneDrive, Google Drive) configure the appropriate properties and use the matching Docker helper scripts in `bin/stage/`.

Docker staging helpers:

```bash
bin/stage/sftp/docker-deploy.sh    # SFTP server
bin/stage/minio/docker-deploy.sh   # MinIO object storage
```

> ⚠️ The stage Docker scripts use default credentials. Always change usernames, passwords, and add TLS before production use.

---

## Documentation & Community

| Resource | Link |
|---|---|
| Full Documentation | https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md |
| Website | https://www.synclite.io |

---

## Patent

SyncLite is backed by patented technology, more info: https://www.synclite.io/about

---

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening a pull request.

## License

SyncLite is licensed under the [Apache License 2.0](LICENSE).
