
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
    <p align="center">
        <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg?style=flat-square" alt="License: Apache 2.0"></a>
        <a href="DOCUMENTATION.md"><img src="https://img.shields.io/badge/Docs-Read_the_Guide-0f766e.svg?style=flat-square" alt="Documentation"></a>
        <a href="GETTING_STARTED.md"><img src="https://img.shields.io/badge/Quickstart-Get_Started-f59e0b.svg?style=flat-square" alt="Getting Started"></a>
        <a href="https://www.synclite.io"><img src="https://img.shields.io/badge/Website-synclite.io-2563eb.svg?style=flat-square" alt="Website"></a>
        <a href="README.md#synclite--build-anything-sync-anywhere-"><img src="https://img.shields.io/badge/Runtime-Embeddable-7c3aed.svg?style=flat-square" alt="Embeddable Runtime"></a>
        <a href="README.md#get-started-in-30-seconds"><img src="https://img.shields.io/badge/Languages-Java%20%7C%20Rust%20%7C%20Python-16a34a.svg?style=flat-square" alt="Java, Rust, and Python"></a>
    </p>
</p>

# SyncLite — Build Anything, Sync Anywhere

**Your app writes to a local embedded database. SyncLite makes every write land in PostgreSQL transactionally — automatically, durably, offline-tolerant — with no CDC pipeline, no message bus, no replication agent to wire up.**

Drop one library into your application and you get a fully-featured embedded database (SQLite, DuckDB, Derby, H2, or HyperSQL) whose every write is durably logged and continuously synced to your destination in the background. Your hot path never touches the network. Your app keeps working offline and catches up when connectivity returns.

```mermaid
flowchart TB
    classDef app  fill:#eef6ff,stroke:#2b6cb0,stroke-width:1px,color:#1a365d
    classDef bad  fill:#fff5f5,stroke:#c53030,stroke-width:1.5px,color:#742a2a
    classDef edb  fill:#fffaf0,stroke:#c98a00,stroke-width:1px,color:#5c3a00
    classDef rt   fill:#fff8e6,stroke:#c98a00,stroke-width:1.5px,color:#5c3a00
    classDef dst  fill:#f0fff4,stroke:#2f855a,stroke-width:1px,color:#22543d

    subgraph Before["TRADITIONAL — app bound to a remote DB"]
        direction LR
        A1["Your App"]:::app
        PG1[("PostgreSQL<br/>(network-bound)")]:::bad
        A1 -- "every read/write<br/>over the network" --> PG1
    end

    subgraph After["SYNCLITE — local-first + background sync"]
        direction LR
        A2["Your App"]:::app
        EDB[("Embedded DB<br/>SQLite / DuckDB<br/>local, always available")]:::edb
        RT["SyncLite Runtime<br/>log + shipper + sync"]:::rt
        PG2[("PostgreSQL")]:::dst
        A2 -- "in-process read/write<br/>(no network in the hot path)" --> EDB
        EDB --> RT
        RT -- "async · durable · offline-tolerant" --> PG2
    end

    Before ==>|"drop in one library"| After
```

| | Traditional (app → remote DB) | **SyncLite (local-first)** |
|---|---|---|
| Read/write latency | network round-trip every op | **in-process, memory-speed** |
| Works offline | ✗ fails without connectivity | **✓ fully offline, syncs on reconnect** |
| Delivery guarantee | app must build retries/dedup | **✓ durable log, exactly-once** |
| Moving parts | app + DB + custom CDC/queue | **✓ one embedded library** |

---

## Get started in 30 seconds

Pick your language and add one dependency. No server to install. No service to configure.

```bash
pip install synclite            # Python — self-contained wheel, batteries included
```

```bash
cargo add synclite-rs           # Rust — cdylib also embeddable from C/C++, Go, Node, Ruby, C#
```

```xml
<!-- Java / Maven -->
<dependency>
    <groupId>io.synclite</groupId>
    <artifactId>synclite</artifactId>
    <version>1.0.0</version>
</dependency>
```

```groovy
// Java / Gradle
implementation 'io.synclite:synclite:1.0.0'
```

The Python wheel and Java jar are **self-contained** — they bundle the native runtime, DuckDB, and the PostgreSQL driver. `pip install` is genuinely all you need on Windows, Linux, and macOS.

---

## Python — SQLite → PostgreSQL

```python
import synclite as sl

DB_PATH   = "sampledevice.db"
POSTGRES  = "postgresql://postgres:postgres@localhost:5432/syncdb"
DB        = "syncdb"
SCHEMA    = "syncschema"

# One call wires up the local logger, the segment shipper,
# and the embedded consolidator that drains into PostgreSQL.
sl.initialize(
    device_type="SQLITE",
    device_name="sampledevice",
    db_path=DB_PATH,
    destination=sl.DestinationOptions(
        dst_type="POSTGRES",
        dst_connection_string=POSTGRES,
        dst_database=DB,
        dst_schema=SCHEMA,
        dst_sync_mode="REPLICATION",
    ),
)

conn = sl.Connection.open(DB_PATH)
conn.execute("CREATE TABLE IF NOT EXISTS orders(id INTEGER PRIMARY KEY, item TEXT, qty INTEGER)")
conn.execute("INSERT INTO orders(id, item, qty) VALUES(?, ?, ?)", [1, "widget", 100])
conn.execute("INSERT INTO orders(id, item, qty) VALUES(?, ?, ?)", [2, "gadget",  50])
conn.commit()

conn.flush()                          # ensure pending writes are shipped before process exits
sl.await_sync(DB_PATH, 30.0)          # optional: block until PostgreSQL confirms apply
conn.close()
```

Every `INSERT` / `UPDATE` / `DELETE` — and every `ALTER TABLE` — is durably logged and applied to PostgreSQL in the background, whether your app is online or not. Full sample: [`synclite-code-samples/python/synclite_rusqlite_postgres.py`](synclite-code-samples/python/synclite_rusqlite_postgres.py).

---

## Java — one jar, full JDBC

```xml
<!-- Maven -->
<dependency>
    <groupId>io.synclite</groupId>
    <artifactId>synclite</artifactId>
    <version>1.0.0</version>
</dependency>
```

```java
import io.synclite.*;
import java.nio.file.Path;
import java.sql.*;
import java.time.Duration;

private static final Path   DB_PATH        = Path.of("sampledevice.db");
private static final String DEVICE_NAME    = "sampledevice";
private static final String POSTGRES_URL   =
        "jdbc:postgresql://localhost:5432/syncdb?user=postgres&password=postgres";
private static final String POSTGRES_DB     = "syncdb";
private static final String POSTGRES_SCHEMA = "syncschema";

// One call wires up the local logger, the segment shipper,
// and the embedded consolidator that drains into PostgreSQL.
SQLite.initialize(DB_PATH, DEVICE_NAME,
    DestinationOptions.builder()
        .dstType(DstType.POSTGRES)
        .connectionString(POSTGRES_URL)
        .database(POSTGRES_DB).schema(POSTGRES_SCHEMA)
        .syncMode(DstSyncMode.REPLICATION)
        .build());

try (Connection conn = DriverManager.getConnection(
        "jdbc:synclite_sqlite:" + DB_PATH);
     Statement s = conn.createStatement()) {
    s.execute("CREATE TABLE IF NOT EXISTS orders(id INTEGER PRIMARY KEY, item TEXT, qty INTEGER)");
    s.execute("INSERT INTO orders VALUES(1, 'widget', 100)");
    s.execute("INSERT INTO orders VALUES(2, 'gadget',  50)");
}

SyncLite.awaitSync(DB_PATH, Duration.ofSeconds(30)); // optional: block until PostgreSQL confirms apply
SQLite.closeDevice(DB_PATH);
```

The in-process consolidator is bundled inside the jar — no external service needed. Full JDBC surface: arbitrary `SELECT`, `JOIN`, multi-statement transactions, stored procedures. Full sample: [`synclite-code-samples/java/SyncliteSqlitePostgresApp.java`](synclite-code-samples/java/SyncliteSqlitePostgresApp.java).

> **Sample failing?** Check `<dbPath>.synclite/<dbName>.trace` (logger errors) and `<userHome>/synclite/job1/workDir/synclite_<deviceName>_<uuid>/synclite_device.trace` (consolidator errors).

---

## Rust — `cargo add synclite-rs`

```bash
cargo add synclite-rs
```

```rust
use synclite::rusqlite::Connection;
use synclite::{DestinationOptions, DeviceType, DstSyncMode, DstType, Result,
               SyncLiteOptions, Value};

const DB_PATH:     &str = "sampledevice.db";
const DEVICE_NAME: &str = "sampledevice";
const POSTGRES:    &str = "postgresql://postgres:postgres@localhost:5432/syncdb";
const DB:          &str = "syncdb";
const SCHEMA:      &str = "syncschema";

// One call wires up the local logger, the segment shipper,
// and the embedded consolidator that drains into PostgreSQL.
synclite::initialize(
    DeviceType::SQLITE,
    DEVICE_NAME,
    DB_PATH,
    Some(DestinationOptions {
        dst_type: DstType::Postgres,
        dst_connection_string: POSTGRES.into(),
        dst_database: Some(DB.into()),
        dst_schema: Some(SCHEMA.into()),
        dst_sync_mode: DstSyncMode::Replication,
    }),
    SyncLiteOptions::default(),
)?;

let mut conn = Connection::open(DB_PATH)?;
conn.execute("CREATE TABLE IF NOT EXISTS orders(id INTEGER PRIMARY KEY, item TEXT, qty INTEGER)", &[])?;
conn.execute("INSERT INTO orders(id, item, qty) VALUES(?, ?, ?)",
    &[Value::Int(1), Value::Text("widget".into()), Value::Int(100)])?;
conn.execute("INSERT INTO orders(id, item, qty) VALUES(?, ?, ?)",
    &[Value::Int(2), Value::Text("gadget".into()),  Value::Int(50)])?;

conn.flush()?;  // ensure pending writes are shipped before process exits
synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30))?; // optional: block until PG confirms
conn.close()?;
```

The Rust crate is also a `cdylib` — embeddable from **Python, Node.js, C/C++, Go, Ruby, C#** via a single native library. Full sample: [`synclite-code-samples/rust/synclite_rusqlite_postgres.rs`](synclite-code-samples/rust/synclite_rusqlite_postgres.rs).

---

## What you get in one library

- **Full embedded SQL.** SQLite, DuckDB, Apache Derby, H2, HyperSQL — all behind the same APIs. Arbitrary `SELECT`, `JOIN`, multi-statement transactions, ad-hoc DDL.
- **Three write APIs.** Plain SQL/JDBC, a typed **Store CRUD** API (`insert`/`update`/`delete`/`selectAll` — no SQL, schema evolves automatically), or a fluent **Stream** append-only API for high-throughput event ingestion.
- **Offline-first.** Works on laptops, edge boxes, phones, and containers with no connectivity. Syncs when the network returns — exactly once, no duplicates.
- **No moving parts.** Logger + shipper + in-process consolidator are all inside the one library. No CDC tool. No Kafka. No replication agent.
- **Any language.** Java jar, Rust crate, Python wheel. The Rust build exposes a `cdylib` ABI: call it from C/C++, Go, Node.js, Ruby, or C#.

---

## Fleet — many apps, many devices, one destination

Any number of apps embed their own runtime, in any language, all shipping to the same staging store and applying to the same destinations:

```mermaid
flowchart LR
    classDef app fill:#eef6ff,stroke:#2b6cb0,stroke-width:1px,color:#1a365d
    classDef rt  fill:#fff8e6,stroke:#c98a00,stroke-width:1.5px,color:#5c3a00
    classDef dst fill:#f0fff4,stroke:#2f855a,stroke-width:1px,color:#22543d

    subgraph Fleet["Many apps · many devices — laptops · servers · edge boxes · containers · phones · IoT"]
        direction TB

        subgraph App1["App / Device 1 — Java"]
            API1["SQL · Store · Stream"]:::app
            RT1["SyncLite Runtime<br/>DB → Log → Shipper → Consolidator"]:::rt
            API1 --> RT1
        end

        subgraph App2["App / Device 2 — Python"]
            API2["SQL · Store · Stream"]:::app
            RT2["SyncLite Runtime<br/>DB → Log → Shipper → Consolidator"]:::rt
            API2 --> RT2
        end

        subgraph App3["App / Device 3 — Rust"]
            API3["SQL · Store · Stream"]:::app
            RT3["SyncLite Runtime<br/>DB → Log → Shipper → Consolidator"]:::rt
            API3 --> RT3
        end

        subgraph AppN["App / Device N — Node · C/C++ · Go · Ruby · C# ..."]
            APIN["SQL · Store · Stream"]:::app
            RTN["SyncLite Runtime<br/>DB → Log → Shipper → Consolidator"]:::rt
            APIN --> RTN
        end
    end

    Stage[("Shared Stage<br/>FS · S3 · MinIO · SFTP")]
    RT1 -- async --> Stage
    RT2 -- async --> Stage
    RT3 -- async --> Stage
    RTN -- async --> Stage

    Stage -- apply --> Dst

    Dst["Current embedded-runtime target<br/>PostgreSQL<br/><br/>Standalone Consolidator<br/>PostgreSQL · MySQL · MSSQL · MongoDB<br/>Iceberg · DuckDB · S3"]:::dst
```

<sub>Inside each runtime: SQL (JDBC for Java, rusqlite for Rust, native bindings for Python / Node / C/C++ / Go / Ruby / C#) plus the Store CRUD and Stream APIs all sit on top of the same embedded DB, WAL logger, shipper, and in-process consolidator. The current embedded runtime path targets PostgreSQL; the standalone Consolidator is the broader multi-destination path.</sub>

---

## SyncLite Devices — three APIs over one runtime

A "device" is a logical embedded DB that the runtime owns end-to-end (storage + log + sync). Pick the API that fits your code:

- **SQL Devices** — full SQLite-syntax-compliant SQL (`SQLite`, `DuckDB`, `Derby`, `H2`, `HyperSQL`). Arbitrary `CREATE`/`ALTER`/`SELECT`/`INSERT`/`UPDATE`/`DELETE`. Use this when you want a real embedded SQL DB that also happens to sync.
- **Store Devices** — `SyncLiteStore` typed CRUD (`SQLITE_STORE`, `DUCKDB_STORE`, …). `insert`/`update`/`delete`/`selectAll` against plain maps; schema evolves automatically. Highest consolidation throughput — no SQL-log parsing on the apply path.
- **Streaming Device** — `SyncLiteStream` fluent `insert`/`insertBatch` over the append-only `STREAMING` device. For high-throughput event capture where UPDATE/DELETE are not needed.

> **Which should I pick?** For a new app, `SQLITE_STORE` is usually the fastest *and* simplest starting point. Reach for SQL devices when you need raw SQL, JOINs, or multi-statement transactions.

---

## Runtime first, tools on top

SyncLite ships as two things:

1. **The Runtime** — what your application embeds. A small library that owns the local DB, the log, the shipper, and the in-process consolidator.
2. **Optional tooling** — webapps and CLIs built on top of the runtime, for teams who want centralized ops, scheduled ETL jobs, IoT ingest, or end-to-end test harnesses. None are required to use the runtime in your code.

---

## Components

### Embeddable runtime — link it into your app

| Component | Description | README |
|---|---|---|
| **SyncLite Runtime (Java)** (`synclite-<version>.jar`) | One jar = JDBC / Store / Stream APIs + logger + shipper + (optional) **in-process consolidator** (via bundled `synclite_jni` native). Call `initialize(dbPath, deviceName, destinationOptions)` for the single-jar topology, or `initialize(dbPath, conf)` for logger-only mode paired with the standalone Consolidator WAR. | [→](synclite-logger-java/README.md) |
| **SyncLite Runtime (Rust)** | Same runtime in Rust (logger + in-process consolidator) as a single `cdylib`. Consumable from **Rust, Python, Node.js, C/C++, Go, Ruby, C#** — anywhere you can load a native library. | [→](synclite-logger-rust/README.md) |

### Optional tooling — built on top of the runtime

Deploy these only when you want a managed platform. They are standard webapps that consume the same runtime under the hood.

| Component | Description | README |
|---|---|---|
| **SyncLite DB** | Wraps the runtime as a tiny local-first HTTP/JSON service. Use it when you want the runtime accessible from a language that doesn't embed the native lib, or when multiple processes share one device. | [→](https://github.com/syncliteio/synclite-db/blob/main/README.md) |
| **SyncLite Client** | Interactive CLI for inspecting and querying SyncLite devices. | [→](https://github.com/syncliteio/synclite-client/blob/main/README.md) |
| **SyncLite Consolidator** | Standalone consolidation service for the central topology — accepts log segments from many devices and applies them to destinations. | [→](https://github.com/syncliteio/synclite-consolidator/blob/main/README.md) |
| **SyncLite DBReader** | Configurable database ETL / replication / migration jobs (source DB → SyncLite devices → destinations). | [→](https://github.com/syncliteio/synclite-dbreader/blob/main/README.md) |
| **SyncLite QReader** | MQTT / IoT connector that lands broker traffic into SyncLite devices. | [→](https://github.com/syncliteio/synclite-qreader/blob/main/README.md) |
| **SyncLite Job Monitor** | Unified job management and scheduling UI for DBReader / QReader / Consolidator jobs. | [→](https://github.com/syncliteio/synclite-job-monitor/blob/main/README.md) |
| **SyncLite Validator** | End-to-end integration test harness for SyncLite pipelines. | [→](https://github.com/syncliteio/synclite-validator/blob/main/README.md) |
| **Sample Web App** | JSP/Servlet demo that embeds SyncLite (Java) in logger-only mode and pairs with the standalone Consolidator WAR for sync. | [→](https://github.com/syncliteio/synclite-sample-web-app/blob/main/README.md) |

#### Tooling — how it fits together

```mermaid
flowchart LR
    classDef src   fill:#eef6ff,stroke:#2b6cb0,color:#1a365d
    classDef tool  fill:#fef5ff,stroke:#805ad5,stroke-width:1.5px,color:#44337a
    classDef dev   fill:#fff8e6,stroke:#c98a00,color:#5c3a00
    classDef ops   fill:#edf2f7,stroke:#4a5568,color:#1a202c
    classDef dst   fill:#f0fff4,stroke:#2f855a,color:#22543d

    SrcDB["Source DBs<br/>Oracle · MySQL · SQL Server<br/>Postgres · DB2 · MongoDB"]:::src
    Brokers["IoT / MQTT brokers<br/>Mosquitto · HiveMQ · ..."]:::src
    Apps["Your Apps<br/>(running embedded runtime)"]:::dev

    DBReader["SyncLite DBReader<br/><sub>scheduled DB → device replication / ETL</sub>"]:::tool
    QReader["SyncLite QReader<br/><sub>broker → device ingest</sub>"]:::tool

    Devices[("SyncLite Stage")]:::ops

    Consolidator["SyncLite Consolidator<br/><sub>standalone service<br/>applies log segments to destinations</sub>"]:::tool

    JobMon["Job Monitor UI<br/><sub>schedule · monitor · alert<br/>DBReader · QReader · Consolidator jobs</sub>"]:::ops
    Client["SyncLite Client<br/><sub>CLI — inspect / query devices</sub>"]:::ops

    Dst["Destinations<br/>Postgres · MySQL · MSSQL · MongoDB<br/>Iceberg · DuckDB · S3"]:::dst

    SrcDB   --> DBReader  --> Devices
    Brokers --> QReader   --> Devices
    Apps    --> Devices
    Devices --> Consolidator --> Dst

    JobMon -. orchestrates .-> DBReader
    JobMon -. orchestrates .-> QReader
    JobMon -. orchestrates .-> Consolidator
    Client -. inspects .-> Devices
```

<sub>Solid lines are data flow. Dashed lines are the control plane. Nothing in this diagram is required by the runtime — reach for these only when you want a managed platform on top of the embedded runtime.</sub>

---

## Deploy the full platform

Use this when you want the central Consolidator + DBReader + QReader + Job Monitor running as services. **No build required** — grab the prebuilt platform zip:

> Download the latest **`synclite-platform-<version>.zip`** from [GitHub Releases](https://github.com/syncliteio/SyncLite/releases), unzip it, and open a terminal in the extracted folder.

```bash
cd bin/
./deploy.sh      # or deploy.bat on Windows   (downloads Tomcat + JDK, deploys all WARs)
./start.sh       # or start.bat on Windows    (starts Tomcat + every SyncLite app)
```

| URL | App |
|---|---|
| http://localhost:8080/synclite-consolidator | Configure and monitor consolidation jobs |
| http://localhost:8080/synclite-sample-app | Create devices, run SQL workloads, see live sync |
| http://localhost:8080/synclite-dbreader | Set up database ETL/replication pipelines |
| http://localhost:8080/synclite-qreader | Set up IoT MQTT connector pipelines |
| http://localhost:8080/synclite-jobmonitor | Manage and schedule all SyncLite jobs |
| http://localhost:8080/manager | Tomcat manager (user: `synclite` / pwd: `synclite`) |

**Sample Web App → Consolidator** (browser-driven, no external source DB)

1. Open [synclite-consolidator](http://localhost:8080/synclite-consolidator) → configure **staging** + a **destination** DB → start the consolidation job.
2. Open [synclite-sample-app](http://localhost:8080/synclite-sample-app) → create a device that logs to the **same** staging location.
3. Run SQL in the sample app and watch rows land in your destination.

**DBReader → Consolidator** (database → database replication/ETL)

1. Open [synclite-consolidator](http://localhost:8080/synclite-consolidator) → configure **staging** + **destination** DB → start the consolidation job.
2. Open [synclite-dbreader](http://localhost:8080/synclite-dbreader) → configure your **source** DB → point its output at the **same** staging location.
3. Start the DBReader job and watch source changes replicate to the destination.

**Docker (all-in-one)**

```bash
cd bin/
./docker-deploy.sh     # Builds synclite-platform image (+ optional SFTP/MinIO + PostgreSQL/MySQL)
./docker-start.sh      # Starts synclite-platform container and optional helpers
./docker-stop.sh       # Stops synclite-platform container and optional helpers
```

> ⚠️ Docker helper scripts use default credentials. Change usernames, passwords, and enable TLS before any production use.

Full walkthrough: [GETTING_STARTED.md - Try the tools together](GETTING_STARTED.md#try-the-tools-together).

---



```mermaid
flowchart TB
    classDef app  fill:#eef6ff,stroke:#2b6cb0,stroke-width:1px,color:#1a365d
    classDef bad  fill:#fff5f5,stroke:#c53030,stroke-width:1.5px,color:#742a2a
    classDef edb  fill:#fffaf0,stroke:#c98a00,stroke-width:1px,color:#5c3a00
    classDef rt   fill:#fff8e6,stroke:#c98a00,stroke-width:1.5px,color:#5c3a00
    classDef dst  fill:#f0fff4,stroke:#2f855a,stroke-width:1px,color:#22543d

    subgraph Before["TRADITIONAL — app bound to a remote DB"]
        direction LR
        A1["Your App"]:::app
        PG1[("PostgreSQL<br/>(network-bound)")]:::bad
        A1 -- "every read/write<br/>over the network" --> PG1
    end

    subgraph After["SYNCLITE — local-first + background sync"]
        direction LR
        A2["Your App"]:::app
        EDB[("Embedded DB<br/>SQLite / DuckDB<br/>local, always available")]:::edb
        RT["SyncLite Runtime<br/>log + shipper + sync"]:::rt
        PG2[("PostgreSQL")]:::dst
        A2 -- "in-process read/write<br/>(no network in the hot path)" --> EDB
        EDB --> RT
        RT -- "async · durable · offline-tolerant" --> PG2
    end

    Before ==>|"drop in one library"| After
```

**Why the SyncLite path wins:** your app reads and writes a **local** embedded DB at in-process speed and keeps working offline, while the SyncLite Runtime durably logs every write and syncs it to your destination in the background. The network moves *off* the critical path — so you get lower latency, offline resilience, and exactly-once delivery **without** wiring up a separate CDC tool, message bus, or replication agent.

| | Traditional (app → remote DB) | **SyncLite (local-first)** |
|---|---|---|
| Read/write latency | network round-trip every op | **in-process, memory-speed** |
| Works offline | ✗ fails without connectivity | **✓ fully offline, syncs on reconnect** |
| Delivery guarantee | app must build retries/dedup | **✓ durable log, exactly-once** |
| Moving parts | app + DB + custom CDC/queue | **✓ one embedded library** |

## Build SyncLite

> **Architecture support.** SyncLite is **64-bit only** — `x86_64` and `aarch64` on Windows / Linux / macOS. 32-bit hosts are not supported because SyncLite Runtime (Rust) depends on the DuckDB engine, which requires a 64-bit host.

**Prerequisites (Java-only build):** Java 25, Apache Maven 3.8.6+

**Additional prerequisites (build all loggers including Rust):**
- Rust toolchain 1.86.0
- Cargo 1.86.0 (bundled with Rust 1.86.0)
- **Native C/C++ toolchain (system linker)** — required by Rust to link the cdylibs:
  - **Windows**: Microsoft C++ Build Tools (provides `link.exe`). Install from <https://visualstudio.microsoft.com/visual-cpp-build-tools/> and select the **"Desktop development with C++"** workload.
  - **Linux**: `build-essential` + `cmake` — e.g. `sudo apt install build-essential pkg-config cmake`.
  - **macOS**: Xcode Command Line Tools — `xcode-select --install`.
- [`cargo-zigbuild`](https://github.com/rust-cross/cargo-zigbuild) and the [Zig](https://ziglang.org/download/) compiler on `PATH`
- Rust standard libraries for Linux x86_64 and aarch64
- **Python 3.8+ and [`maturin`](https://www.maturin.rs/)** — for the host-platform Python wheel:
  ```bash
  python -m pip install maturin
  # Windows: pip install delvewheel  |  Linux: pip install auditwheel  |  macOS: pip install delocate
  ```
  Skip with `-DskipPythonWheel=true` (also skipped automatically by `-DskipNonJavaLoggers=true`).

```bash
git clone --recurse-submodules https://github.com/syncliteio/SyncLite.git SyncLite
cd SyncLite
```

### Build flavors

| # | Flavor | What it produces |
|---|---|---|
| 1 | **Full platform** (default) | `target/synclite-platform-<rev>.zip` — Tomcat scripts + WARs + tools + samples + multi-arch native runtime |
| 2 | **Full platform, Java-only** | Same as #1 but no `lib/native/` (no Rust toolchain required) |
| 3 | **Runtime** (recommended for app developers) | `target/synclite-runtime-<rev>.zip` — slim zip with `lib/java/` (synclite jar) + multi-arch `lib/native/` (Rust cdylibs) + cross-language `sample-apps/{cpp,java,python,rust}` |

```bash
# 1. Full platform (default)
mvn -Drevision=1.0.0 clean install

# 2. Full platform, Java-only (no Rust toolchain required)
mvn -Drevision=1.0.0 -DskipNonJavaLoggers=true clean install

# 3. Runtime only — slim embeddable zip
mvn -Drevision=1.0.0 -DruntimeOnly=true clean install

# Fastest build on a host without zig
mvn -Drevision=1.0.0 -DruntimeOnly=true -DskipRustCrossCompile=true -DskipTests clean install
```

> For just the Java jar or just the Rust cdylibs, build individual subprojects directly: `cd synclite-logger-java && mvn install` or `cd synclite-logger-rust && cargo build --workspace --release`.

The cross-compile toolchain (for Linux x86\_64 and aarch64 cdylibs):

```bash
cargo install cargo-zigbuild
rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu
# zig must be on PATH — download from https://ziglang.org/download/
```

> The `bin/deploy.sh` / `bin/deploy.bat` scripts download Apache Tomcat 9.0.117 and OpenJDK 25 automatically. No manual installation needed for a quick start.

## Release Structure

### Runtime-only zip (`-DruntimeOnly=true`)

```
synclite-runtime-1.0.0/
+-- lib/
|   +-- java/
|   |   +-- synclite-<version>.jar              # Add to your app classpath
|   |   +-- synclite.conf                       # Default logger configuration
|   +-- native/                                 # Multi-arch native cdylibs (Rust runtime)
|   |   +-- include/                            # C / C++ ABI headers (synclite.h, synclite.hpp)
|   |   +-- synclite_<version>.dll                    # Windows host build
|   |   +-- synclite_<version>.dll.lib                # Windows import library
|   |   +-- synclite_<version>.lib                    # Windows static library
|   |   +-- libsynclite_<version>_linux_x86_64.so     # cross-compiled
|   |   +-- libsynclite_<version>_linux_aarch64.so    # cross-compiled
|   |   +-- libsynclite_<version>.dylib               # only if built on macOS
|   |   +-- synclite.conf
|   +-- python/
|   |   +-- synclite-<version>-cp38-abi3-win_amd64.whl
|   |   +-- synclite-<version>-cp38-abi3-manylinux_2_28_x86_64.whl
|   |   +-- synclite-<version>-cp38-abi3-manylinux_2_28_aarch64.whl
|   +-- rust/
|       +-- synclite-source/                    # Self-contained Cargo workspace
+-- sample-apps/                                # One sample per language
|   +-- cpp/                                    # CMake-based, links lib/native
|   +-- java/                                   # javac + lib/java/synclite-<version>.jar
|   +-- python/                                 # pip install lib/python/*.whl
|   +-- rust/                                   # cargo run, path-deps into lib/rust
+-- LICENSE
+-- synclite_platform_version.txt
```

### Full platform zip (default)

```
synclite-platform-1.0.0/
+-- bin/
|   +-- deploy.sh / deploy.bat        # One-command setup: downloads Tomcat + JDK, deploys WARs
|   +-- start.sh / start.bat          # Start Tomcat + all SyncLite apps
|   +-- stop.sh / stop.bat            # Graceful shutdown
|   +-- docker-deploy.sh / docker-start.sh / docker-stop.sh
|   +-- stage/sftp/ stage/minio/      # Docker scripts for staging servers
|   +-- dst/postgresql/ dst/mysql/    # Docker scripts for destination DBs
+-- lib/                              # Same as runtime-only zip above
+-- tools/
|   +-- synclite-client/  synclite-db/  synclite-dbreader/
|   +-- synclite-qreader/ synclite-jobmonitor/ synclite-validator/
|   +-- synclite-sample-app/
+-- sample-apps/                      # cpp / java / python / rust
```

---

## Using SyncLite Logger (Java)

Add `synclite-<version>.jar` to your project, then:

```java
import io.synclite.*;
import java.nio.file.Path;
import java.sql.*;

Path dbDir  = Path.of(System.getProperty("user.home"), "synclite", "db");
Path dbPath = dbDir.resolve("myapp.db");
Path conf   = dbDir.resolve("synclite.conf");

Class.forName("io.synclite.SQLite");
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
import io.synclite.SQLiteStore;
import io.synclite.SyncLiteStore;

Class.forName("io.synclite.SQLiteStore");
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
import io.synclite.Streaming;
import io.synclite.SyncLiteStream;

Class.forName("io.synclite.Streaming");
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

`io.synclite.Jedis` is a drop-in subclass of `redis.clients.jedis.Jedis`. Every write is durably committed to a `SQLITE_STORE` device before being forwarded to Redis, and the cache is repopulated from the store on restart.

```java
import io.synclite.Jedis;

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

SyncLite DB is a local-first HTTP/JSON database service that wraps embedded databases with built-in SyncLite logging and replication (by coupling it with SyncLite Consolidator), so any language can call it over HTTP.

The sample below uses Python for brevity; the same HTTP calls work from Go (`net/http`) and Node.js (`fetch` / `axios`).

Deploy `synclite-db-1.0.0.war` (bundled under `tools/synclite-db/`) to Tomcat, open `http://localhost:8080/synclite-db`, and configure + start the DB server from the browser GUI. It then serves the HTTP/JSON API on the port set in the GUI.

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

```go
// Go client (plain HTTP — no SDK needed)
package main

import (
        "bytes"
        "net/http"
)

func postJSON(url string, body string) error {
        _, err := http.Post(url, "application/json", bytes.NewBufferString(body))
        return err
}

func main() {
        base := "http://localhost:5555/synclite"
        _ = postJSON(base, `{"db-type":"SQLITE","db-name":"myapp","synclite-logger-options":{"local-data-stage-directory":"/tmp/stage"},"sql":"initialize"}`)
        _ = postJSON(base, `{"db-name":"myapp","sql":"CREATE TABLE IF NOT EXISTS t1(a INT, b TEXT)"}`)
        _ = postJSON(base, `{"db-name":"myapp","sql":"INSERT INTO t1 VALUES(?, ?)","arguments":[[1,"hello"],[2,"world"]]}`)
}
```

```javascript
// Node.js client (plain HTTP — no SDK needed)
const BASE = "http://localhost:5555/synclite";

async function post(body) {
    await fetch(BASE, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
}

await post({
    "db-type": "SQLITE",
    "db-name": "myapp",
    "synclite-logger-options": { "local-data-stage-directory": "/tmp/stage" },
    sql: "initialize",
});

await post({
    "db-name": "myapp",
    sql: "CREATE TABLE IF NOT EXISTS t1(a INT, b TEXT)",
});

await post({
    "db-name": "myapp",
    sql: "INSERT INTO t1 VALUES(?, ?)",
    arguments: [[1, "hello"], [2, "world"]],
});
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

## Sponsorship & Support

SyncLite is open source and free to use. If it adds value to your work, please consider sponsoring its continued development — sponsorships fund maintenance, new features, and community support.

[![Sponsor SyncLite](https://img.shields.io/badge/Sponsor-%E2%9D%A4-db61a2?logo=github-sponsors&logoColor=white)](https://github.com/sponsors/syncliteio)

You can sponsor us via [GitHub Sponsors](https://github.com/sponsors/syncliteio) (see [.github/FUNDING.yml](.github/FUNDING.yml)). Every contribution, big or small, is greatly appreciated. ⭐ Starring the repo and spreading the word helps too!

---

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening a pull request.

## License

SyncLite is licensed under the [Apache License 2.0](LICENSE).
