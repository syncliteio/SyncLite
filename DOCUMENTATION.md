# SyncLite Platform — Complete Technical Documentation

> **License:** Apache License 2.0  

> **Website:** https://github.com/syncliteio/SyncLite

> **Full Online Docs:** https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md

> **Community:** See GitHub Issues for support and discussion: https://github.com/syncliteio/SyncLite/issues

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Components](#3-components)
4. [Prerequisites & Build](#4-prerequisites--build)
5. [Installation & Quick Start](#5-installation--quick-start)
6. [SyncLite Logger (Java JDBC) + SyncLite Runtime (Rust/Python/C++)](#6-synclite-logger-java-jdbc--synclite-runtime-rustpythonc)
   - [Device Types](#61-device-types)
   - [Configuration Reference](#62-configuration-reference-syncliteconf)
   - [Java JDBC API](#63-java-jdbc-api)
   - [SyncLiteStore API](#64-synclitestore-api)
   - [SyncLiteStream API](#65-synclitestream-api)
   - [Jedis (Redis-Compatible) API](#66-jedis-redis-compatible-api)
   - [Kafka Producer API](#67-kafka-producer-api)
   - [Python Usage](#68-python-usage)
   - [Device Encryption](#69-device-encryption)
   - [Command Handler](#610-command-handler)
   - [Rust Library](#611-rust-library)
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
Data Producers (Edge/App Layer)
    - SyncLite Logger (Java JDBC)
    - SyncLite DB (HTTP/JSON server)
    - SyncLite DBReader (ETL source)
    - SyncLite QReader (MQTT IoT)
                                 |
                                 v
Staging Storage (Local FS / SFTP / S3 / MinIO / Kafka / OneDrive / Google Drive / NFS)
                                 |
                                 v
SyncLite Consolidator (central always-on sink)  OR  Embedded Consolidator (in-process)
                                 |
                                 +--> PostgreSQL / MySQL / SQL Server / Oracle / SQLite / DuckDB
                                 +--> Amazon Redshift / ClickHouse / MongoDB
                                 +--> Apache Parquet / Delta Lake / Iceberg / CSV on S3
```

**Flow:** sources produce compact binary log files → files are shipped to staging storage → SyncLite Consolidator delivers them to one or more destinations in real time.

**Two consolidator topologies, same wire format.** The Consolidator engine is available in two interchangeable forms:

- **Standalone (central) Consolidator WAR** — the always-on web app at `http://<host>:8080/synclite-consolidator`. Best when many devices fan in to one place and you want centralized monitoring.
- **Embedded Consolidator** — the same engine running *in-process* inside your application. The Java jar (`synclite-<version>.jar`) and the Rust runtime (`synclite` crate) both bundle it via a JNI-loaded native engine. Best for single-process deployments — drop in one library, point it at a destination, and the app self-replicates with no separate service.

Both produce the same `.sqllog` segments, so you can mix devices (some logger-only against the central Consolidator, others fully embedded) on the same staging storage.

---

## 3. Components

| Component | Description | Port / URL |
|---|---|---|
| **SyncLite for Java** | One jar (`synclite-<version>.jar`) = JDBC / Store / Stream APIs + logger + shipper + in-process consolidator (via bundled `synclite_jni` native). Logger-only or full-runtime is just an API-call choice at `initialize(...)` time. | (embedded library — no port) |
| **SyncLite Rust Runtime** | Same runtime in Rust (`synclite` crate) — logger + shipper + in-process consolidator. Consumable from Rust, Python, Node.js, C/C++, Go, Ruby, C# via a single `cdylib`. | (embedded library — no port) |
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

> **Architecture support.** SyncLite is **64-bit only** — `x86_64` and `aarch64` on Windows / Linux / macOS. 32-bit hosts are not supported because the embedded Rust runtime depends on the DuckDB engine, which requires a 64-bit host.

### Prerequisites

| Requirement | Version |
|---|---|
| Java (JDK) | 25 |
| Apache Maven | 3.8.6+ |
| Rust toolchain (`rustup`, `cargo`) | stable |
| Zig compiler (for cross-arch Rust runtime packaging) | latest stable |
| cargo-zigbuild (for Linux cross-compiled cdylibs) | latest |

> The `bin/deploy.sh` / `bin/deploy.bat` scripts download Apache Tomcat 9.0.117 and OpenJDK 25 automatically. No manual installation needed for a quick start.

### Build the entire platform

```bash
git clone --recurse-submodules git@github.com:syncliteio/SyncLite.git SyncLite
cd SyncLite
mvn -Drevision=oss clean install
```

### Build flavors

SyncLite has **three** top-level reactor build flavors, ordered from largest to smallest output. Pick the smallest one that meets your need.

| # | Flavor | Produces | Rust toolchain? |
|---|---|---|---|
| 1 | **Full platform** (default) | `target/synclite-platform-<rev>.zip` — Tomcat scripts + WARs + tools + samples + multi-arch native | Required |
| 2 | **Full platform, Java-only** | Same as #1 but no `lib/native/` | Not required |
| 3 | **Runtime** | `target/synclite-runtime-<rev>.zip` — just `lib/java/` + multi-arch `lib/native/` | Required |

```bash
# 1. Full platform (default)
mvn -Drevision=oss clean install

# 2. Full platform, Java-only
mvn -Drevision=oss -DskipNonJavaLoggers=true clean install

# 3. Runtime — fastest path for embedded use
mvn -Drevision=oss -DruntimeOnly=true clean install
```

> For just the synclite logger jar, or just the Rust cdylibs, build the subproject directly (`cd synclite-logger-java && mvn install`, or `cd synclite-logger-rust && cargo build --workspace --release`).

### Build accelerators

These switches combine with any flavor above:

- `-DskipTests` — skip JUnit + Rust device-integration tests.
- `-DskipRustCrossCompile=true` — skip the two Linux cross-compile cargo executions (use on hosts without `cargo-zigbuild` + `zig`; host-arch cdylib still built). Only relevant for flavors #1 and #3.

```bash
# Fastest full platform build
mvn -Drevision=oss -DskipTests clean install

# Fastest runtime build on a host without zig
mvn -Drevision=oss -DruntimeOnly=true -DskipRustCrossCompile=true -DskipTests clean install
```

The full platform release is assembled under `SyncLite/target/synclite-platform-oss/`.
The runtime build produces `SyncLite/target/synclite-runtime-oss/` (and `.zip`).

If you only want the embedded Rust runtime (`synclite` crate) and not the full Tomcat web stack, build just the Rust workspace:

```bash
cd synclite-logger-rust
cargo build --workspace
```

If you are packaging multi-arch Rust runtime natives (Linux x86_64 / aarch64 from a non-Linux host), install the cross-build prerequisites first:

```bash
cargo install cargo-zigbuild
rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu
# Ensure zig is installed and available on PATH
zig version
```

### Build individual components

To build specific SyncLite components individually (useful for development or faster iteration), run the following from the repository root.

- Build the Logger module (Java samples and JAR):

```bash
cd synclite-logger-java/logger
mvn -Drevision=oss clean install
```

- Build the Consolidator (server):

```bash
cd synclite-consolidator
mvn -Drevision=oss clean install
```

- Build SyncLite DB server (root module):

```bash
cd synclite-db/root
mvn -Drevision=oss clean install
```

- Build the CLI client:

```bash
cd synclite-client/client
mvn -Drevision=oss clean install
```

- Build the Job Monitor web app:

```bash
cd synclite-job-monitor/root
mvn -Drevision=oss clean install
```

- Build the Rust runtime workspace and bindings:

```bash
cd synclite-logger-rust
cargo build --workspace
```

- Build the DBReader, QReader and Validator modules:

```bash
cd synclite-dbreader/root
mvn -Drevision=oss clean install

cd synclite-qreader/root
mvn -Drevision=oss clean install

cd synclite-validator/root
mvn -Drevision=oss clean install
```

When these individual builds complete, their artifacts appear under their respective `target/` directories. The full platform assembly is produced by running `mvn -Drevision=oss clean install` from the repository root.

`deploy.sh` / `deploy.bat` automatically:
- Downloads Apache Tomcat 9.0.117
- Downloads OpenJDK 25
- Deploys all SyncLite WAR files into Tomcat

If your use case is Rust/Python/C++ embedding through the Rust runtime, you do not need these deploy scripts. They are only for the web applications (Consolidator, DBReader, QReader, Job Monitor, Sample App).

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

## 6. SyncLite Logger (Java JDBC) + SyncLite Runtime (Rust/Python/C++)

**SyncLite Logger** is an embeddable Java library (JDBC driver) that makes Java applications sync-ready with minimal code changes. It wraps popular embedded databases and transparently captures every SQL transaction into compact binary log files.

> **SyncLite Runtime is the language bridge.** The same pipeline is also
> shipped as the [`synclite`](https://github.com/syncliteio/SyncLite/tree/main/synclite-logger-rust)
> Rust runtime (logger + consolidator), consumable from Rust directly and from
> Python/C++ via bindings. See [section 6.11](#611-rust-library) for runtime APIs.
> The rest of section 6 (config keys, log format, device categories) applies to
> both the Java logger and the Rust runtime.

```
Your App  +  SyncLite Logger  +  Embedded DB
     │
      v  (SQL log files)
  Staging Storage  (local / SFTP / S3 / MinIO / Kafka / OneDrive / …)
     │
      v
  SyncLite Consolidator
     │
      v
  Destination DB / Data Warehouse / Data Lake
```

### SyncLite Log Format

Although SyncLite writes its log files as a compact binary blob, the on-disk
format is intentionally simple: each log segment is a SQLite file that hosts a
single command log table (commonly named `commandlog`). Each row records an
ordered change and includes fields such as `change_sequence_number` (sequence),
`commit_id` (epoch ms), `sql` (the statement text), `argcnt` (number of bound
arguments) and a series of typed argument columns (`arg1`…`arg16`) stored as
BLOBs (the table can be extended with additional `argN` columns if needed).

Choosing SQLite as the log format gives SyncLite several practical benefits:
- ACID transactions and durability are provided by the underlying SQLite engine,
    so log segments represent consistent, replayable units of work.
- Single-file portability makes device directories easy to stage, upload, and
    inspect with standard SQLite tools across languages and platforms.
- Wide language and tooling support reduces connector complexity — consumers
    can read SQL + typed args directly instead of parsing proprietary binary
    encodings.
- High insert performance and compact storage make SQLite a good fit for both
    store-style CRUD logs and SQL-style command logs used by ORF (Open Replication
    Format).

The `commandlog` is the canonical replication unit inside each SQLite log
segment. Below is a concise description of the on-disk layout and how tools
should treat it when implementing cross-tool portability.

Schema (recommended canonical layout):

```sql
CREATE TABLE commandlog (
    change_sequence_number INTEGER PRIMARY KEY,
    commit_id             INTEGER, -- epoch millis
    sql                   TEXT,
    argcnt                INTEGER,
    arg1                  BLOB,
    arg2                  BLOB,
    -- ... up to arg16; add more argN columns as needed with ALTER TABLE
    arg16                 BLOB
);
```

### Concurrent writers & txn-file model

Some embedded SQL engines allow multiple transactions to commit concurrently. To support that safely while keeping on-disk segments easy to consume, SyncLite separates the concerns of (a) persisting per-commit SQL rows and (b) publishing a deterministic, serialized stream of commit events.

- Per-commit txn files: for each committed transaction the logger stages a self-contained SQLite file that contains a `commandlog` table with all rows from that commit. Typical names: `0.sqllog.1778468342490.txn`, `0.sqllog.1778468342582.txn` (prefix ties the txn to a segment).
- Master/segment sqllog: the segment file (e.g. `0.sqllog`) acts as the serialized publication log. Instead of embedding concurrent commit rows directly into the master file, the logger writes a small control entry (a `REPLAY_TXN` record) into the master sqllog that references the published txn file's `commit_id`.

This pattern gives consumers a simple iteration model: read `REPLAY_TXN` entries from the master sqllog in order, and for each one open the referenced txn file and apply its `commandlog` rows in sequence. It preserves deterministic ordering of commit publication even when the producer's database engine allowed true concurrency.

Producer responsibilities (summary):

1. Create and fully flush the per-commit txn SQLite file containing that commit's `commandlog` rows.
2. Append a single `REPLAY_TXN(commit_id, file_name, ...)` control record into the master segment sqllog and flush it.

This ensures that a consumer which encounters the `REPLAY_TXN` entry can safely open and read the corresponding txn file. For single-writer producers (where concurrency is not a concern) the logger may instead write `commandlog` rows directly into the main segment file.

Naming conventions recap:

- Segment (master) sqllog: `0.sqllog`, `1.sqllog`, …
- Per-commit txn files: `<segment>.sqllog.<commit_id>.txn` (e.g. `0.sqllog.1683840001000.txn`)
- Metadata file beside a segment: `<segment>.synclite.metadata` (SQLite file with `metadata(key TEXT, value TEXT)`).

**Example: application statements and how `synclite-logger` records them**

Application DDL/DML executed against a database:

```sql
CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO users (id, name) VALUES (1, 'Alice');
UPDATE users SET name = 'Alice Cooper' WHERE id = 1;
DELETE FROM users WHERE id = 1;
ALTER TABLE users ADD COLUMN email TEXT;
DROP TABLE users;
```

How these operations might appear in `commandlog` as captured by `synclite-logger`:

| change_sequence_number | commit_id      | sql                                                           | argcnt | arg1         | arg2 |
|------------------------:|:---------------|:-------------------------------------------------------------|-------:|:-------------|:-----|
| 1                       | 1683840000000  | CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)        | 0      | -            | -    |
| 2                       | 1683840001000  | INSERT INTO users (id, name) VALUES (?, ?)                   | 2      | 1            | Alice|
| 3                       | 1683840001000  |                                                              | 2      | 2            | Bob  |
| 4                       | 1683840002000  | UPDATE users SET name = ? WHERE id = ?                      | 2      | Alice Cooper | 1    |
| 5                       | 1683840003000  | DELETE FROM users WHERE id = ?                               | 1      | 1            | -    |
| 6                       | 1683840004000  | ALTER TABLE users ADD COLUMN email TEXT                      | 0      | -            | -    |
| 7                       | 1683840005000  | DROP TABLE users                                             | 0      | -            | -    |

Notes:

- `sql` stores the executed DDL/DML (literal statements or parameterized with `?`).
- `argN` columns contain parameter values when statements are parameterized; `-` denotes no parameter.
- `operation_id` is NOT a `commandlog` column. The logger maintains an internal `operation_id` counter that is incremented as records are appended, and that value is recorded in the per-device transaction table `synclite_txn` at commit time (single-writer devices update the single `synclite_txn` row; multi-writer devices INSERT a `(commit_id, operation_id)` row per commit). Consumers should read `synclite_txn` if they need the per-commit `operation_id` metadata.

Key points and usage notes:

- Ordered changes: `change_sequence_number` provides a monotonic, replayable
    sequence for deterministic application.
- Typed arguments: `argN` columns store bound parameter values as BLOBs; the
    logger populates `argcnt` to indicate how many `argN` slots are used.
- Durability: each SQLite file is an ACID-backed segment — consumers can open
    the file with any SQLite client to inspect or replay changes.
- Extensibility: if you need more than 16 arguments, add `arg17`, `arg18`,
    etc., via `ALTER TABLE` when bootstrapping a device; readers should handle
    missing columns gracefully.
- Metadata: alongside the segment file (e.g., `t1.db`) SyncLite writes a
    small SQLite metadata file (`t1.db.synclite.metadata`) that contains a
    `metadata` table (`key TEXT, value TEXT`) with keys such as
    `uuid`, `device-name`, `database-name`, `log-segment-sequence-number`, and
    `status` (e.g., `NEW/READY_TO_APPLY` / `APPLIED`). Consumers should read
    metadata to decide processing semantics.

Inspecting and consuming segments:
- Quick inspect with SQLite CLI: `sqlite3 t1.db 'SELECT * FROM commandlog ORDER BY change_sequence_number;'`.
- Consumers that reapply changes should use `change_sequence_number` and
    `commit_id` for ordering and idempotency checks.

Why this works well as an Open Replication Format:
- Files are single-file, portable, and language-agnostic — any tool with a
    SQLite reader can access the data without a proprietary decoder.
- The combination of SQL text plus typed bound parameters allows downstream
    systems to choose between applying the raw SQL or interpreting it as CDC-style
    operations.

Together, these characteristics make SyncLite's SQLite-based `commandlog`
segments a practical, lightweight Open Replication Format for cross-tool
portability and integrations.

### Device Types

SyncLite devices are grouped into three user-facing categories:

- **SQL Devices**: Full SQL-compatible embedded databases (SQLite, DuckDB, Apache Derby, H2, HyperSQL). These provide complete SQL semantics and are well suited when applications need to run arbitrary queries or DDL locally. For replication, SyncLite captures SQL/command logs produced by these devices; the Consolidator then deduces CDC-style operations from those logs before applying them to destinations.

- **Store Devices**: CRUD-oriented store variants (`*_STORE`) that expose the `SyncLiteStore` API (`insert`, `update`, `delete`, `selectAll`) instead of a free-form SQL surface. Store devices:
  - Offer a typed, simpler CRUD API with automatic schema evolution (auto-adding missing columns).
  - Produce logs that the Consolidator applies directly to destinations — they do not require a separate two-step deduce-and-apply processing used for SQL devices.
  - Are preferable for applications that need deterministic CRUD semantics and straightforward replication.

- **Streaming Device**: The `STREAMING` device implements append-only ingestion and exposes `SyncLiteStream` APIs (`insert`, `insertBatch`). It's optimized for high-throughput event capture and does not provide UPDATE/DELETE semantics.

> **Which device should I pick?** Store devices (`*_STORE`) and the `STREAMING` device emit pre-formed row events that the Consolidator applies directly to the destination — no SQL-log parsing or CDC-deduction step on the apply path, so they deliver the highest end-to-end consolidation throughput. Reach for a SQL device (`SQLITE`, `DUCKDB`, `DERBY`, `H2`, `HYPERSQL`) when your app actually needs raw SQL, JOINs, multi-statement transactions in one connection, or ad-hoc DDL beyond the schema-evolution the Store API handles for you. For a brand-new app, `SQLITE_STORE` is usually the fastest *and* simplest starting point.

Notes:
- Appender and DBLogger device types are internal implementation variants and are intentionally not documented as primary device types.


### Adding SyncLite Logger to your project

**Maven:**

```xml
<dependency>
    <groupId>io.synclite</groupId>
    <artifactId>synclite</artifactId>
    <version><!-- latest version --></version>
</dependency>
```

**Jar:** Copy `synclite-${revision}.jar` from `lib/java/` in the platform release into your project classpath.

> **DuckDB device users:** the DuckDB JDBC driver (`org.duckdb:duckdb_jdbc`)
> ships ~50 MB of native libraries and is **not bundled** in the
> SyncLite jar. If your application uses any DuckDB device (`DUCKDB`,
> `DUCKDB_STORE`, `DUCKDB_APPENDER`, …) add it explicitly to your project
> alongside SyncLite, pinned to the same version SyncLite is built
> against:
>
> ```xml
> <dependency>
>     <groupId>org.duckdb</groupId>
>     <artifactId>duckdb_jdbc</artifactId>
>     <version>1.5.2.0</version>
> </dependency>
> ```
>
> The same note applies to the full-runtime `synclite-consolidator` jar.
> Non-DuckDB users can ignore this dependency entirely.

---

### 6.1 Device Types

SyncLite devices are grouped into three user-facing categories. Documentation and examples should use this three-way classification when describing device behavior and choosing a device for a workload.

- **SQL Devices** — Full SQL-compatible embedded databases (SQLite, DuckDB, Apache Derby, H2, HyperSQL). Use these when applications require the full SQL surface (arbitrary queries, DDL, DML). Replication for SQL devices captures SQL/command logs which the Consolidator later processes into CDC-style operations before applying them to destinations.

- **Store Devices** — CRUD-oriented store variants (`*_STORE`) that expose the `SyncLiteStore` API (`insert`, `update`, `delete`, `selectAll`) instead of a free-form SQL surface. Store devices:
    - Provide a typed, simpler CRUD API with automatic schema evolution (auto-adding missing columns).
    - Produce logs that the Consolidator applies directly to destinations — they do not require a separate two-step deduce-and-apply processing used for SQL devices.
    - Are ideal for deterministic CRUD semantics and lower application complexity.

- **Streaming Device** — The `STREAMING` device models append-only ingestion and exposes `SyncLiteStream` APIs (`insert`, `insertBatch`). It's optimized for high-throughput event capture and intentionally does not provide UPDATE/DELETE semantics.

> **Which device should I pick?** Store devices (`*_STORE`) and the `STREAMING` device emit pre-formed row events that the Consolidator applies directly to the destination — no SQL-log parsing or CDC-deduction step on the apply path, so they deliver the highest end-to-end consolidation throughput. Reach for a SQL device (`SQLITE`, `DUCKDB`, `DERBY`, `H2`, `HYPERSQL`) when your app actually needs raw SQL, JOINs, multi-statement transactions in one connection, or ad-hoc DDL beyond the schema-evolution the Store API handles for you. For a brand-new app, `SQLITE_STORE` is usually the fastest *and* simplest starting point.

Examples (common device identifiers): `SQLITE`, `DUCKDB`, `DERBY`, `H2`, `HYPERSQL`, `SQLITE_STORE`, `DUCKDB_STORE`, `DERBY_STORE`, `H2_STORE`, `HYPERSQL_STORE`, `STREAMING`.

Notes:
- Appender and DBLogger device types are internal implementation variants and are intentionally omitted from user-facing documentation. If you need to tune or use an appender-style device, treat it as an advanced/internal option and consult implementation notes or the codebase directly.

---

### 6.2 Configuration Reference (`synclite.conf`)

A full sample configuration file is at `synclite-logger-java/logger/src/main/resources/synclite.conf`. All properties are optional unless noted otherwise.

#### Device Stage Configuration

```properties
# Staging storage type (required)
# Options: FS | SFTP | S3 | MINIO | MS_ONEDRIVE | GOOGLE_DRIVE | KAFKA
device-stage-type=FS

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

# Skip restart recovery for non-SQL devices
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

#### SQL vs. Store Device Tuning

```properties
# For SQL devices: disable async logging (synchronous mode, maximum durability)
disable-async-logging-for-transactional-device=false

# For Store devices: enable async logging (maximum throughput)
# NOTE: config key remains `enable-async-logging-for-appender-device` for backward compatibility
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
        Path conf   = dbDir.resolve("synclite.conf");

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

#### Store device (typed CRUD over SQL backend)

```java
Class.forName("io.synclite.logger.SQLiteStore");
SQLiteStore.initialize(dbPath, conf);

try (SyncLiteStore store = SQLiteStore.open(dbPath)) {
    store.createTable("orders", new LinkedHashMap<>(Map.of(
        "id", "INTEGER PRIMARY KEY",
        "status", "TEXT"
    )));
    store.insert("orders", Map.of("id", 1, "status", "created"));
    store.update("orders", Map.of("status", "shipped"), Map.of("id", 1));
}
SQLiteStore.closeDevice(dbPath);
```

#### Streaming device (high-throughput append-only)

```java
Class.forName("io.synclite.logger.Streaming");
Streaming.initialize(dbPath, conf);

try (SyncLiteStream stream = SyncLiteStream.open(dbPath)) {
    stream.createTable("logs", new LinkedHashMap<>(Map.of(
        "ts", "BIGINT",
        "msg", "TEXT"
    )));
    stream.insert("logs", Map.of(
        "ts", System.currentTimeMillis(),
        "msg", "high-throughput record"
    ));
}
Streaming.closeDevice(dbPath);
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
SQLiteStore.initialize(dbPath, Path.of("synclite.conf"));

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
Streaming.initialize(dbPath, Path.of("synclite.conf"));

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
Path conf   = Path.of("synclite.conf");

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

SyncLite supports two Python entry points at different maturity levels:

| | Today | Coming |
|---|---|---|
| Package | `synclite` ctypes wrapper (single file: `lib/python/synclite.py`) | `synclite-logger-python` PyO3 wheel |
| Backed by | C ABI in `synclite-bindings-c` cdylib (same binary as C / C++ / Java JNI) | PyO3 over the Rust runtime |
| Install | None \u2014 ships in every release zip alongside `lib/native/libsynclite_oss.*` | `pip install synclite-logger-python` |
| Surface | `Runtime.open_config`, `log_sql`, `commit`, `flush_log`, `rollback`, `close` | Rich `Connection` / `Statement` / `await_sync`, plus DB-API 2.0, SyncLiteStore, SyncLiteStream, Redis / Kafka compatibility |
| Parameter binding | No (values inlined in SQL) | Yes |
| CPython matrix | Any 3.8+ on any OS/arch where `lib/native/` ships a binary | Per-(CPython \u00d7 OS \u00d7 arch) wheel |

No JVM, no JAR, no `jaydebeapi` / `jpype` bridge in either case.

#### Today \u2014 `synclite` ctypes wrapper

The release zip already contains everything you need: a single Python
file (`lib/python/synclite.py`) plus the platform cdylib in
`lib/native/`. The wrapper finds the cdylib automatically when run from
the unpacked zip layout; outside it, point at the library with
`SYNCLITE_NATIVE_LIB` or `SYNCLITE_NATIVE_DIR`.

```python
import synclite as sl  # from lib/python/synclite.py

# Minimal SQLite-device config shipping to PostgreSQL.
with open("synclite_logger.conf", "w") as f:
    f.write(
        "device-name=sampledevice\n"
        "db-engine=SQLITE\n"
        "device-type=SQLITE\n"
        "db-path=myapp.db\n"
        "local-data-stage-directory=synclite-stage\n"
        "dst-type=POSTGRES\n"
        "dst-connection-string=postgresql://user:pw@localhost:5432/syncdb\n"
        "dst-database=syncdb\n"
        "dst-schema=public\n"
        "dst-sync-mode=CONSOLIDATION\n"
    )

with sl.Runtime.open_config("synclite_logger.conf") as rt:
    rt.log_sql("CREATE TABLE IF NOT EXISTS events(id INT PRIMARY KEY, payload TEXT)")
    rt.log_sql("INSERT INTO events(id, payload) VALUES(1, 'hello from Python')")
    rt.log_sql("INSERT INTO events(id, payload) VALUES(2, 'row two')")
    rt.commit()
    rt.flush_log()
# \u2191 logged locally; the in-process shipper + consolidator drain to PostgreSQL.
```

The C ABI logs SQL strings only \u2014 there is no parameter binding yet \u2014
so values are inlined. The richer `Connection` / `Statement` API below is
where this is heading.

#### Coming \u2014 `synclite-logger-python` (PyO3 wheel)

The five samples under
[`synclite-code-samples/synclite-runtime/python/`](synclite-code-samples/synclite-runtime/python/)
(`synclite_rusqlite*.py`, `synclite_streaming.py`, `synclite_duckdb*.py`)
are the canonical reference for the upcoming PyO3 wheel \u2014 mirroring the
Rust API 1:1 (`Connection`, `Statement`, `DuckDBConnection`,
`DuckDBStatement`, plus module-level `initialize` and `await_sync`):

```python
import synclite as sl  # via the upcoming synclite-logger-python wheel

DB_PATH = "myapp.db"

sl.initialize(
    device_type="SQLITE",
    device_name="sampledevice",
    db_path=DB_PATH,
    destination=sl.DestinationOptions(
        dst_type="POSTGRES",
        dst_connection_string="postgresql://user:pw@localhost:5432/syncdb",
        dst_database="syncdb",
        dst_schema="public",
    ),
)

conn = sl.Connection.open(DB_PATH)
conn.execute("CREATE TABLE IF NOT EXISTS events(id INT PRIMARY KEY, payload TEXT)")

stmt = conn.prepare("INSERT INTO events(id, payload) VALUES(?, ?)")
stmt.execute([1, "hello from Python"])

stmt = conn.prepare("INSERT INTO events(id, payload) VALUES(?, ?)")
stmt.add_batch([2, "row two"])
stmt.add_batch([3, "row three"])
stmt.execute_batch()

for row in conn.query("SELECT id, payload FROM events ORDER BY id"):
    print(row)

conn.commit()
conn.flush()
# Demo only: await_sync is shown here to make sample output deterministic.
# In production, sync runs continuously in the background.
sl.await_sync(DB_PATH, 30.0)
# Optional runtime controls:
# sl.pause_sync(DB_PATH)
# sl.resume_sync(DB_PATH)
conn.close()
```

For DuckDB, swap `sl.Connection` for `sl.DuckDBConnection` and pass
`device_type="DUCKDB"` to `sl.initialize`.

##### Store / Streaming devices

Write a config file with `device-type=SQLITE_STORE` (or `STREAMING`,
`DUCKDB_STORE`) and open via `open_with_config`:

```python
import synclite as sl

CONF_PATH = "store_device.conf"

sl.initialize(
    device_type="SQLITE_STORE",
    device_name="sampledevice",
    db_path="store.db",
    config_path=CONF_PATH,
)

conn = sl.Connection.open_with_config(CONF_PATH)
conn.execute("CREATE TABLE IF NOT EXISTS orders(id INT PRIMARY KEY, status TEXT)")
conn.execute("INSERT INTO orders(id, status) VALUES(?, ?)", [1, "created"])
conn.execute("INSERT INTO orders(id, status) VALUES(?, ?)", [2, "confirmed"])
conn.close()
```

---

### 6.9 Device Encryption

SyncLite Logger (Java JDBC runtime) supports transparent encryption of log files before they are shipped to staging storage. Configure encryption in `synclite.conf`:

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

> Rust runtime note: device encryption is not supported in the Rust runtime yet.

---

### 6.10 Command Handler

The **Command Handler** enables bi-directional communication: SyncLite Consolidator drops command files into the command stage directory, and the logger polls that directory on a fixed interval, reads the files, and dispatches them — either to your Java callback (`INTERNAL`) or to a shell script (`EXTERNAL`).

Each command file is named `<timestamp>.<command-text>`. The logger processes them in timestamp order, exactly once (it remembers the last processed timestamp across restarts).

#### `synclite.conf` settings

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

### 6.11 Rust Library

The [`synclite`](https://github.com/syncliteio/SyncLite/tree/main/synclite-logger-rust)
crate is a pure-Rust port of the SyncLite Logger pipeline — logger,
shipper, and embedded consolidator in a single binary. It speaks the
same on-disk SQL-log format as the Java Logger, so devices written by
the Rust runtime can be consolidated by the standard SyncLite
Consolidator (and vice versa).

**Install**

```toml
# Cargo.toml
[dependencies]
synclite = "<latest>"
```

**Hello, SyncLite (Rust)**

```rust
use synclite::rusqlite::Connection;
use synclite::{DestinationOptions, DeviceType, DstSyncMode, DstType, Result, SyncLiteOptions, Value};
use postgres::{Client, NoTls};

fn main() -> Result<()> {
    const DB_PATH: &str = "orders.db";
    const DEVICE_NAME: &str = "orders-device";

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

    // Demo only: await_sync is shown here to make sample output deterministic.
    // In production, sync runs continuously in the background.
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

    // Optional runtime controls:
    // synclite::pause_sync(DB_PATH)?;
    // synclite::resume_sync(DB_PATH)?;

    conn.close()?;
    Ok(())
}
```

**API surface**

| Item | Notes |
|------|-------|
| `initialize(device_type, device_name, db_path, destination, options)` | One-shot bootstrap. Idempotent per `db_path`. `device_name` must be alphanumeric. |
| `DeviceType` | `Sqlite`, `Duckdb` (SQL device); `Sqlite` also backs STORE/STREAMING devices. |
| `DestinationOptions` | `dst_type` (`Sqlite` / `Duckdb` / `Postgres`), `dst_connection_string`, `dst_database` (required for Postgres/DuckDB, rejected for SQLite), `dst_schema` (required for Postgres, optional for DuckDB, rejected for SQLite), `dst_sync_mode` (`Consolidation` / `Replication`). |
| `SyncLiteOptions` | Mirrors most Java `synclite.conf` keys (log batch size, ship interval, retention, etc.; device encryption is not supported yet in Rust runtime). |
| `synclite::SyncLite` | Type alias for `Logger`, kept for symmetry with the Java `SyncLite` facade. |

**Embedded native helper**

The crate bundles the `synclitecdc` native CDC helper for Linux
x86_64/x86 and Windows x86_64/x86. On first use it is extracted next to
the device DB so SQL devices work without any external install step.

**Device reinitialize**

The Rust runtime exposes an in-place reinitialize that wipes per-device
local state and the device's destination metadata so the next
`synclite::initialize` re-seeds from scratch under the same UUID,
device-name, device-type, and destination wiring:

```rust
// Preserve destination data; only local state is wiped.
synclite::reinitialize(db_path, false)?;

// REPLICATION mode: also drop the user tables owned by this device.
// CONSOLIDATION mode: dropping is a no-op (the destination is shared
// across many devices, so dropping would be unsafe for siblings).
synclite::reinitialize(db_path, true)?;
```

A trigger-file protocol lets out-of-process tooling force a reinit on
the next bring-up without linking against the crate — drop
`reinitialize.<device-name>` or
`reinitialize_with_clean_destination.<device-name>` alongside the
database file and `synclite::initialize` will fire the reinit and
delete the trigger.

**Pause / resume sync**

Halt destination consolidation for a device without stopping the
logger. While paused, the in-process logger keeps appending segments
locally and the shipper keeps publishing them to the upload root —
only the consolidator's apply step is held back. On `resume_sync` the
queued segments drain in order.

```rust
synclite::pause_sync(db_path)?;
assert!(synclite::is_sync_paused(db_path)?);
// ...keep writing; segments accumulate locally but do not reach the
//    destination database...
synclite::resume_sync(db_path)?;
```

Both calls are idempotent; the paused state is persisted in a sentinel
file under the device home, so it survives process restarts.

Trigger-file protocol: drop `pause_sync.<device-name>` or
`resume_sync.<device-name>` alongside the database file and the next
`synclite::initialize` toggles state and deletes the trigger.

**Sync status, latency, statistics**

Three read-only helpers report what the consolidator is doing for a
device. They open SQLite files the consolidator has already produced
— no workers are started and no destination round-trips are made.

```rust
let st = synclite::sync_status(db_path)?;
// st.state is SyncState::NotInitialized | Paused | Running
// plus raw status / status_description / last_heartbeat_time_ms.

let s = synclite::sync_statistics(db_path)?;
// log_segments_applied, processed_oper_count, processed_txn_count,
// processed_log_size, last_consolidated_commit_id, last_heartbeat_time_ms.

let l = synclite::sync_latency(db_path)?;
// l.source_commit_id  = MAX(commit_id) from device synclite_txn
// l.applied_commit_id = last commit_id applied at the destination
// l.latency_ms        = source - applied (wall-clock ms); -1 when the
//                       applied side is unknown.
```

Because every `commit_id` is a `System.currentTimeMillis()` value
emitted by the logger, `latency_ms` is the actual wall-clock sync lag.

**Runnable samples**

[`synclite-code-samples/synclite-runtime/rust/`](synclite-code-samples/synclite-runtime/rust/)
is a self-contained Cargo project with one example per device shape:

```sh
cd synclite-code-samples/synclite-runtime/rust
cargo run --example synclite_rusqlite        # SQLite SQL device
cargo run --example synclite_duckdb          # DuckDB SQL device
cargo run --example synclite_duckdb_store    # DuckDB STORE device
cargo run --example synclite_sqlite_store    # SQLite STORE device
cargo run --example synclite_streaming       # SQLite STREAMING device
```

For the full crate layout, internals, and build instructions see
[`synclite-logger-rust/README.md`](synclite-logger-rust/README.md).

---

## 7. SyncLite DB (HTTP/JSON Server)

**SyncLite DB** is a standalone database server that wraps the same embedded databases (SQLite, DuckDB, Derby, H2, HyperSQL) and exposes them over HTTP as a JSON API — making SyncLite accessible to **any programming language**.

```
Your App (any language)  --HTTP/JSON-->  SyncLite DB Server  -->  Staging Storage  -->  SyncLite Consolidator  -->  Destination
```

### 7.1 Starting the Server

```bash
# Linux / macOS
cd tools/synclite-db
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
  "db-name": "myapp",
  "synclite-logger-options": {
    "local-data-stage-directory": "/home/alice/synclite/job1/stageDir",
    "device-stage-type": "FS"
  },
  "sql": "initialize"
}
```

- Applications send `db-name` (not a file path). SyncLite DB resolves the physical database path internally under the server DB root directory.
- `db-name` is also used internally as SyncLite Logger `device-name`.
- Logger settings are passed as a nested JSON object in `synclite-logger-options` (or `synclite-logger-config` object alias). File-path based logger config is deprecated.
- If `synclite-logger-options` is omitted, server default logger config is used.

**`db-type` values:** `SQLITE` · `DUCKDB` · `DERBY` · `H2` · `HYPERSQL` · `STREAMING` · `SQLITE_APPENDER` · `DUCKDB_APPENDER` · `DERBY_APPENDER` · `H2_APPENDER` · `HYPERSQL_APPENDER`

`*_APPENDER` values are legacy compatibility names; for new documentation and usage guidance, prefer Store / Streaming terminology.

#### DDL — Create a table

```json
{
  "db-name": "myapp",
  "sql": "CREATE TABLE IF NOT EXISTS events(id INT, payload TEXT)"
}
```

#### DML — Insert (with positional parameters)

```json
{
  "db-name": "myapp",
  "sql": "INSERT INTO events VALUES(?, ?)",
  "arguments": [[1, "edge-event-1"], [2, "edge-event-2"]]
}
```

Each sub-array in `arguments` is one row. This performs a batch insert in a single HTTP call.

#### Explicit transaction

```json
// 1. Begin — response contains "txn-handle"
{ "db-name": "myapp", "sql": "begin" }

// 2. Execute inside transaction
{
  "db-name": "myapp",
  "sql": "INSERT INTO events VALUES(?, ?)",
  "txn-handle": "<uuid-from-begin-response>",
  "arguments": [[3, "three"]]
}

// 3. Commit
{ "db-name": "myapp", "sql": "commit", "txn-handle": "<uuid>" }

// 3. (alternatively) Rollback
{ "db-name": "myapp", "sql": "rollback", "txn-handle": "<uuid>" }
```

#### SELECT — basic query

```json
{
  "db-name": "myapp",
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
  "db-name": "myapp",
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
  "db-name": "myapp",
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
{ "db-name": "myapp", "sql": "close" }
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
              json={"db-name": "myapp", "sql": "SELECT 1"},
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

result = signed_post({"db-name": "myapp", "sql": "SELECT 1"})
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
    "db-name": "myapp",
    "synclite-logger-options": {
        "local-data-stage-directory": "/tmp/synclite/stageDir",
        "device-stage-type": "FS"
    },
    "sql": "initialize"
})

# Create table
requests.post(BASE, json={
    "db-name": "myapp",
    "sql": "CREATE TABLE IF NOT EXISTS t1(a INT, b TEXT)"
})

# Batch insert
requests.post(BASE, json={
    "db-name": "myapp",
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
    --synclite-logger-config /path/to/synclite.conf

# Remote mode (via SyncLite DB server)
synclite-cli.sh /path/to/myapp.db \
    --device-type SQLITE \
    --synclite-logger-config /path/to/synclite.conf \
    --server http://localhost:5555
```

### Supported Device Types

`SQLITE` · `DUCKDB` · `DERBY` · `H2` · `HYPERSQL` · `STREAMING` · `SQLITE_APPENDER` · `DUCKDB_APPENDER` · `DERBY_APPENDER` · `H2_APPENDER` · `HYPERSQL_APPENDER`

`*_APPENDER` values are legacy compatibility names; for new documentation and usage guidance, prefer Store / Streaming terminology.

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
SyncLite DBReader ─┤-->  Staging Storage  -->  SyncLite Consolidator  -->  Destination(s)
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
| Data Warehouses | Amazon Redshift, ClickHouse |
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
| **Destination type** | PostgreSQL, MySQL, Amazon Redshift, ClickHouse, etc. |
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
Source DB(s)  -->  SyncLite DBReader  -->  Staging Storage  -->  SyncLite Consolidator  -->  Destination(s)
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
             v
    MQTT Broker(s)  --subscribe-->  SyncLite QReader  -->  Staging Storage  -->  SyncLite Consolidator  -->  Destination
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
SyncLite DBReader jobs       --+-->  SyncLite Job Monitor  (web UI)
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
      v
  Edge Device  -->  Staging Storage  -->  SyncLite Consolidator  -->  Destination DB
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
| **Configuration** | Shows how to pass a `synclite.conf` to `SyncLite.initialize()` |

### Architecture

```
Browser  --HTTP-->  SyncLite Sample Web App (Tomcat)
                         │  SyncLite Logger (embedded JDBC)
                 v
                   Edge Databases (SQLite / DuckDB / …)
                         │  sync log files
                 v
                   Local staging directory
                         │
                 v
             SyncLite Consolidator  -->  Destination DB
```

Source entry points in `synclite-sample-web-app/web/src/`:
- `main/webapp/` — JSP views (create device, run workload, dashboard)
- `main/java/` — Servlet handlers and SyncLite Logger integration code
- `main/resources/synclite.conf` — sample logger configuration

---

## 15. Staging Storage Setup

The staging storage is the intermediary layer between edge devices and SyncLite Consolidator. Configure `local-data-stage-directory` in `synclite.conf` for local/NFS staging. For remote staging, configure the appropriate section and use the matching Docker helper scripts.

### Local / NFS

```properties
device-stage-type=FS
local-data-stage-directory=/path/to/shared/nfs/mount/stage
```

### SFTP

```properties
device-stage-type=SFTP
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
device-stage-type=MINIO
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
device-stage-type=S3
local-data-stage-directory=/path/to/local/buffer
s3:access-key=AKIAIOSFODNN7EXAMPLE
s3:secret-key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
s3:data-stage-bucket-name=my-synclite-stage
s3:command-stage-bucket-name=my-synclite-commands
```

### Apache Kafka

```properties
device-stage-type=KAFKA
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
./docker-deploy.sh    # Builds synclite-platform image, deploys platform container
./docker-start.sh     # Starts synclite-platform container and optional helpers
./docker-stop.sh      # Stops synclite-platform container and optional helpers
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
+-- bin/
|   +-- deploy.sh / deploy.bat          # One-command setup: downloads Tomcat + JDK, deploys WARs
|   +-- start.sh / start.bat            # Start Tomcat + all SyncLite apps
|   +-- stop.sh / stop.bat              # Graceful shutdown
|   +-- docker-deploy.sh                # Docker image build + deploy
|   +-- docker-start.sh / docker-stop.sh
|   +-- tomcat-users.xml                # Default Tomcat user config (synclite/synclite)
|   +-- stage/
|   |   +-- sftp/                       # Docker scripts for SFTP staging server
|   |   +-- minio/                      # Docker scripts for MinIO staging server
|   +-- dst/
|       +-- postgresql/                 # Docker scripts for PostgreSQL destination
|       +-- mysql/                      # Docker scripts for MySQL destination
|
+-- lib/
|   +-- logger/
|   |   +-- java/
|   |       +-- synclite-${revision}.jar  # synclite jar (add to edge app classpath)
|   +-- consolidator/
|       +-- synclite-consolidator-<version>.war
|
+-- tools/
|   +-- synclite-client/                # CLI client (synclite-cli.sh / .bat)
|   +-- synclite-db/                    # SyncLite DB HTTP server
|   +-- synclite-dbreader/              # DBReader WAR + launcher
|   +-- synclite-qreader/               # QReader WAR + launcher
|   +-- synclite-job-monitor/           # Job Monitor WAR
|   +-- synclite-validator/             # Validator WAR
|
+-- sample-apps/
    +-- synclite-logger/
    |   +-- java/                       # Java sample apps
    |   |   +-- SyncliteDeviceApp.java
    |   |   +-- SyncLiteStoreDeviceApp.java
    |   |   +-- SyncLiteStreamingApp.java
    |   |   +-- SyncLiteStoreAPIApp.java
    |   |   +-- SyncLiteStreamAPIApp.java
    |   |   +-- SyncLiteKafkaProduceApp.java
    |   |   +-- SyncLiteJedisAPIApp.java
    |   +-- python/                     # Python samples (ctypes wrapper today;
    |   |                               #   PyO3 synclite-logger-python on the roadmap)
    |   |   +-- synclite_device_app.py
    |   |   +-- synclite_store_device_app.py
    |   |   +-- synclite_streaming_app.py
    |   |   +-- synclite_duckdb_app.py
    |   +-- jsp-servlet/                # Sample web app WAR
    +-- synclite-db/
        +-- (language SDK samples)
```

---

## 18. Security Considerations

- **Default credentials:** The default Tomcat credentials are `synclite` / `synclite`. Change them in `bin/tomcat-users.xml` before any network-exposed deployment.
- **Docker default credentials:** All Docker helper scripts use default usernames and passwords. Always change credentials and add TLS before production use.
- **Staging storage credentials:** SFTP passwords, S3/MinIO access keys, and Kafka credentials appear in `synclite.conf`. Secure this file with appropriate file permissions and use secret management systems in production.
- **Device encryption:** Supported in Java Logger via `device-encryption-key-file` in `synclite.conf` (pre-existing DER public key file). Register the corresponding private key in Consolidator job configuration. Rust runtime device encryption is not supported yet.
- **Network exposure:** SyncLite DB's HTTP server has no TLS built in — place it behind a reverse proxy with TLS in production.
- **Authentication:** Always configure Bearer token or HMAC app-auth for SyncLite DB in any environment accessible over a network.

---

## 19. Patent & License

**License:** SyncLite is licensed under the [Apache License 2.0](LICENSE).

**Patent:** SyncLite is backed by patented technology. More info: https://www.synclite.io/about

---

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening a pull request.

---
