# Getting Started with SyncLite

> **Build Anything, Sync Anywhere** — the embeddable database runtime with built-in sync.
>
> Full documentation: https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md

---

## What Is SyncLite?

**SyncLite is a lightweight, embeddable database runtime.** Drop one library into your app and you get a fully-featured embedded database (SQLite, DuckDB, Apache Derby, H2, or HyperSQL) whose every write is durably logged and continuously synced to wherever you want — another database, a data warehouse, a data lake, or just a file in object storage.

No server to install. No daemon to babysit. No CDC pipeline to wire up. Your application links a jar, a crate, or a native library and ships.

```text
your app  ──►  SyncLite Runtime (embedded DB + log + shipper + sync)  ──►  Postgres / MySQL / Snowflake / S3 / ...
```

### What you get without installing anything

- **One library, full stack.** Embedded SQL database + write-ahead logger + segment shipper + (optional) in-process consolidator — all inside your process.
- **Pick your language.** Two first-class SyncLite Runtimes — **Java** (jar) and **Rust** (crate); the Rust build is embeddable from **Python, Node.js, C/C++, Go, Ruby, C#** via a single `cdylib`.
- **Pick your local DB.** SQLite, DuckDB, Apache Derby, H2, HyperSQL — all behind the same APIs.
- **Pick your write style.** Plain **JDBC / SQL**, a typed **Store CRUD** API (`insert` / `update` / `delete` / `selectAll`), a fluent **Stream** append-only API, or a drop-in **Jedis** subclass for Redis users.
- **Offline-first, single binary.** Works on laptops, edge boxes, mobile-class hardware, and inside containers without any external dependency.
- **Sync is just config.** Point the runtime at a destination and writes start flowing — no separate CDC tool, no Kafka, no replication agent.

### Runtime — what your app embeds

Any number of apps / devices each embed their own runtime, in any
supported language, all sharing a stage and applying to the same
destinations — no central server in the hot path.

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

    Dst["Destinations<br/>Postgres · MySQL · MSSQL · MongoDB<br/>Iceberg · DuckDB · S3"]:::dst
```

<sub>Inside each runtime: SQL (JDBC for Java, rusqlite for Rust, native
bindings for Python / Node / C/C++ / Go / Ruby / C#) plus the Store
CRUD and Stream APIs all sit on top of the same embedded DB, WAL
logger, shipper, and in-process consolidator.</sub>

---

## Runtime first, tools on top

SyncLite ships as two things:

1. **The Runtime** — what your application embeds. This is the core of the project: a small library that owns the local DB, the log, the shipper, and (in the full-runtime jar / Rust crate) the in-process consolidator that pushes data to destinations.
2. **Optional tooling** — webapps and CLIs built **on top of** the same runtime, for teams who want centralized ops, scheduled ETL jobs, IoT ingest, or end-to-end test harnesses. None of them are required to use the runtime in your code.

If you're a developer building an app, you only need group 1. If you're standing up a data platform, group 2 is there when you need it.

### Components

**Embeddable runtime — link it into your app**

| Component | What It Does | README |
|---|---|---|
| **SyncLite Runtime (Java)** (`synclite-<version>.jar`) | One jar = JDBC / Store / Stream APIs + logger + shipper + (optional) **in-process consolidator** (via bundled `synclite_jni` native). Call `initialize(dbPath, deviceName, destinationOptions)` for the single-jar topology, or `initialize(dbPath, conf)` for logger-only mode paired with the standalone Consolidator WAR. | [→](synclite-logger-java/README.md) |
| **SyncLite Runtime (Rust)** | Same runtime in Rust (logger + in-process consolidator) as a single `cdylib`. Consumable from **Rust, Python, Node.js, C/C++, Go, Ruby, C#** — anywhere you can load a native library. | [→](synclite-logger-rust/README.md) |

**Optional tooling — built on top of the runtime**

Deploy these only when you want a managed platform. They are standard webapps that consume the same runtime under the hood.

| Component | What It Does | README |
|---|---|---|
| **SyncLite DB** | Wraps the runtime as a tiny local-first HTTP/JSON service. Use it when you want the runtime accessible from a language that doesn't (yet) embed the native lib, or when multiple processes share one device. | [→](https://github.com/syncliteio/synclite-db/blob/main/README.md) |
| **SyncLite Client** | Interactive CLI for inspecting and querying SyncLite devices. | [→](https://github.com/syncliteio/synclite-client/blob/main/README.md) |
| **SyncLite Consolidator** | Standalone consolidation service for the central topology — accepts log segments from many embedded devices / edge applications and applies them to destinations. | [→](https://github.com/syncliteio/synclite-consolidator/blob/main/README.md) |
| **SyncLite DBReader** | Configurable database ETL / replication / migration jobs (source DB → SyncLite devices → destinations). | [→](https://github.com/syncliteio/synclite-dbreader/blob/main/README.md) |
| **SyncLite QReader** | MQTT / IoT connector that lands broker traffic into SyncLite devices. | [→](https://github.com/syncliteio/synclite-qreader/blob/main/README.md) |
| **SyncLite Job Monitor** | Unified job management and scheduling UI for DBReader / QReader / Consolidator jobs. | [→](https://github.com/syncliteio/synclite-job-monitor/blob/main/README.md) |
| **SyncLite Validator** | End-to-end integration test harness for SyncLite pipelines. | [→](https://github.com/syncliteio/synclite-validator/blob/main/README.md) |
| **Sample Web App** | JSP/Servlet demo that embeds SyncLite (Java) in **logger-only** mode and pairs with the standalone Consolidator WAR for sync. | [→](https://github.com/syncliteio/synclite-sample-web-app/blob/main/README.md) |

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

<sub>Solid lines are data flow. Dashed lines are the control plane.
Nothing in this diagram is required by the runtime — reach for these
only when you want a managed platform on top of the embedded
runtime.</sub>

---

## SyncLite Devices — three APIs over one runtime

A "device" is just a logical embedded DB that the runtime owns end-to-end (storage + log + sync). Pick the API surface that fits your code, not the other way around:

- **SQL Devices** — full, SQLite-syntax-compliant SQL access (`SQLite`, `DuckDB`, `Derby`, `H2`, `HyperSQL`). Run arbitrary `CREATE` / `ALTER` / `SELECT` / `INSERT` / `UPDATE` / `DELETE` through any of the language runtimes (Java, Rust, Python, C++). Use this when you want a real embedded SQL DB and just happen to also want it synced.
- **Store Devices** — `SyncLiteStore` typed CRUD (`SQLITE_STORE`, `DUCKDB_STORE`, `DERBY_STORE`, `H2_STORE`, `HYPERSQL_STORE`). `insert` / `update` / `delete` / `selectAll` against plain maps; schema evolves automatically. Use this when you want a simple, stable replication contract without writing SQL.
- **Streaming Device** — `SyncLiteStream` fluent `insert` / `insertBatch` over the append-only `STREAMING` device. Use this for high-throughput event capture where UPDATE/DELETE are not needed.

All three surfaces produce the same log format and use the same shipper + consolidator under the covers, so you can mix and match devices inside a single application.

> **Which device should I pick?** Store devices (`*_STORE`) and the `STREAMING` device emit pre-formed row events that the Consolidator applies directly to the destination — no SQL-log parsing or CDC-deduction step on the apply path, so they deliver the highest end-to-end consolidation throughput. Reach for a SQL device when your app actually needs raw SQL, JOINs, multi-statement transactions in one connection, or ad-hoc DDL beyond the schema-evolution the Store API handles for you. For a brand-new app, `SQLITE_STORE` is usually the fastest *and* simplest starting point.

---

## Step 1 — Build SyncLite

> **Architecture support.** SyncLite is **64-bit only** — `x86_64` and `aarch64` on Windows / Linux / macOS. 32-bit hosts are not supported because SyncLite Runtime (Rust) depends on the DuckDB engine, which requires a 64-bit host.

### Prerequisites (Java-only build)

| Requirement | Version |
|---|---|
| Java | 25 |
| Apache Maven | 3.8.6+ |
| Git | any recent version |

### Additional prerequisites (build all loggers including SyncLite Runtime (Rust))

| Requirement | Version |
|---|---|
| Rust toolchain (`rustup`, `cargo`) | 1.86.0 |
| Native C/C++ toolchain (system linker) — see callout below | platform default |
| [`cargo-zigbuild`](https://github.com/rust-cross/cargo-zigbuild) | latest |
| [Zig](https://ziglang.org/download/) compiler on `PATH` | latest stable |
| Rust standard libraries for Linux x86_64 and aarch64 | — |
| Python interpreter (`python` on `PATH`) | 3.8+ |
| [`maturin`](https://www.maturin.rs/) (PyO3 wheel builder) | latest stable; install with `python -m pip install maturin` |
| Per-OS wheel-repair tool (bundles native DLL/SO/dylib deps into the wheel) | Windows: `pip install delvewheel` — Linux: `pip install auditwheel` — macOS: `pip install delocate` |

> **Native C/C++ toolchain is required in addition to Rust.** Rust shells out to the platform linker to produce the cdylibs, and the DuckDB / SQLite crates ship native code that needs a C/C++ compiler.
>
> - **Windows**: install [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) and select the **"Desktop development with C++"** workload (MSVC v143 + Windows 10/11 SDK). Without this, `cargo build` fails with `error: linker 'link.exe' not found`. Run the build from the **"x64 Native Tools Command Prompt for VS"** (or any shell where `link.exe` is on `PATH`).
> - **Linux**: install `build-essential` (gcc, ld, make) plus `cmake` and `pkg-config`. Debian/Ubuntu: `sudo apt install build-essential cmake pkg-config`. Fedora/RHEL: `sudo dnf groupinstall "Development Tools" && sudo dnf install cmake pkgconf-pkg-config`.
> - **macOS**: `xcode-select --install` (Xcode Command Line Tools).

The Rust cdylibs for **Linux x86_64 and aarch64** are cross-compiled on every host so a single `mvn package` produces a complete, multi-arch `lib/native/` payload. Install the cross-compile toolchain once on the build host:

```bash
cargo install cargo-zigbuild
rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu
# zig must be on PATH — download from https://ziglang.org/download/
zig version
```

> If `mvn package` fails with `error: no such command: zigbuild`, you are missing `cargo-zigbuild` — run `cargo install cargo-zigbuild` and retry.

macOS (`libsynclite_<rev>.dylib`) still requires running the build on a macOS host — the Apple SDK isn't redistributable so it cannot be cross-compiled from Windows or Linux.

> The `bin/deploy.sh` / `bin/deploy.bat` scripts download **Apache Tomcat 9.0.117** and **OpenJDK 25** automatically — no manual JDK installation required for a quick start of the optional platform.

### Clone

```bash
git clone --recurse-submodules https://github.com/syncliteio/SyncLite.git SyncLite
cd SyncLite
```

### Build flavors

SyncLite has **three** Maven build flavors, ordered from largest to smallest output. Pick the smallest one that meets your need.

| # | Flavor | Produces | Rust toolchain? |
|---|---|---|---|
| 1 | **Full platform** (default) | `target/synclite-platform-<rev>.zip` — Tomcat scripts + WARs + tools + samples + multi-arch native runtime | Required |
| 2 | **Full platform, Java-only** | Same as #1 but no `lib/native/` | Not required |
| 3 | **Runtime** (recommended for app developers) | `target/synclite-runtime-<rev>.zip` — `lib/java/` (synclite jar) + multi-arch `lib/native/` (Rust cdylibs) + cross-language `sample-apps/{cpp,java,python,rust}` | Required |

```bash
# 1. Full platform (default) — Tomcat platform zip with WARs, tools, all language samples, and the multi-arch Rust runtime
mvn -Drevision=1.0.0 clean install

# 2. Full platform, Java-only — same Tomcat platform zip as #1 but no lib/native/ (no Rust toolchain required)
mvn -Drevision=1.0.0 -DskipNonJavaLoggers=true clean install

# 3. Runtime — slim embeddable zip: synclite jar + multi-arch native cdylibs + sample-apps/{cpp,java,python,rust}
mvn -Drevision=1.0.0 -DruntimeOnly=true clean install
```

> **What `-DruntimeOnly=true` does:** activates a Maven profile that reduces the reactor to just the `synclite-logger-java/logger` module and switches the assembly from the full `synclite-platform-<rev>.zip` to the slim `synclite-runtime-<rev>.zip`. Skips the consolidator, dbreader, qreader, job-monitor, validator, sample-web-app, db, and client modules.

> **What `-DskipNonJavaLoggers=true` does:** skips all parent-pom Rust executions (host build + Linux x86_64 + Linux aarch64) and excludes `lib/native/` from the assembly. It also auto-activates `-DskipRustCrossCompile=true` and `-DskipRustTests=true`. Use whenever you don't have a Rust toolchain on the build host.

### Build accelerators

These switches combine with any flavor above:

- **`-DskipTests`** — skip JUnit + Rust device-integration tests.
- **`-DskipRustCrossCompile=true`** — skip the two Linux cross-compile cargo executions (`x86_64-unknown-linux-gnu` + `aarch64-unknown-linux-gnu`). Use on hosts without `cargo-zigbuild` + `zig` on `PATH`; the host-arch cdylib is still built. Only relevant for flavors #1 and #3 (flavor #2 already skips all Rust).

```bash
# Fastest full platform build (skips all tests)
mvn -Drevision=1.0.0 -DskipTests clean install

# Fastest runtime build on a host without zig — host-arch cdylib only, no Linux cross-compile, no tests
mvn -Drevision=1.0.0 -DruntimeOnly=true -DskipRustCrossCompile=true -DskipTests clean install
```

### Build SyncLite Runtime (Rust) directly (no Maven packaging)

If you only need the Rust crate / cdylib for embedding in Rust, Python, Node.js, C/C++, Go, Ruby, or C#, you can skip Maven entirely and build the Rust workspace directly:

```bash
cd synclite-logger-rust
cargo build --workspace
```

> On Windows, root-level Cargo commands such as `cargo test --manifest-path synclite-logger-rust/Cargo.toml ...` also inherit the repository's `.cargo/config.toml`, which keeps `DUCKDB_DOWNLOAD_LIB=true` enabled so DuckDB's prebuilt `duckdb.dll` / `duckdb.lib` artifacts are resolved automatically.

### Release structure

The **runtime** flavor (#3) assembles under `SyncLite/target/synclite-runtime-1.0.0/`:

```
synclite-runtime-1.0.0/
+-- lib/
|   +-- java/
|   |   +-- synclite-<version>.jar                    # Add to your app classpath
|   |   +-- synclite.conf                             # Default logger configuration
|   +-- native/                                       # Multi-arch Rust runtime cdylibs
|   |   +-- include/                                  # C / C++ ABI headers (synclite.h, synclite.hpp)
|   |   +-- libsynclite_<version>.dll                 # Windows host build
|   |   +-- libsynclite_<version>.lib                 # Windows import library
|   |   +-- libsynclite_<version>_linux_x86_64.so     # cross-compiled (omitted if -DskipRustCrossCompile=true)
|   |   +-- libsynclite_<version>_linux_aarch64.so    # cross-compiled (omitted if -DskipRustCrossCompile=true)
|   |   +-- libsynclite_<version>.dylib               # only if built on macOS
|   |   +-- synclite.conf
|   +-- python/
|   |   +-- synclite-<version>-cp38-abi3-*.whl        # Host-platform PyO3 wheel
|   +-- rust/
|       +-- synclite-source/                          # Cargo workspace consumed offline by sample-apps/rust
+-- sample-apps/                                      # cpp / java / python / rust (one sample per language)
+-- LICENSE
+-- synclite_platform_version.txt
```

The **full platform** flavors (#1 and #2) assemble under `SyncLite/target/synclite-platform-1.0.0/`:

```
synclite-platform-1.0.0/
+-- bin/                                              # deploy / start / stop, Docker helpers
+-- lib/                                              # Same as runtime zip above (java, native, python, rust)
+-- tools/                                            # synclite-{client,db,dbreader,qreader,job-monitor,validator,sample-app}
+-- sample-apps/                                      # cpp / java / python / rust (one sample per language)
```

---

## Step 2 — Try the Embedded Runtime (Java → PostgreSQL)

The fastest way to see SyncLite in action is to drop the single jar into a Java app and sync writes straight into PostgreSQL — no Tomcat, no separate Consolidator service.

### Spin up a local PostgreSQL destination

Use the bundled Docker helper:

```bash
cd target/synclite-platform-1.0.0/bin/dst/postgresql/
./docker-deploy.sh    # starts PostgreSQL on localhost:5432 (user: postgres / pwd: postgres)
```

Or use any existing PostgreSQL with a database `syncdb` and schema `syncschema`.

### Run the bundled sample

```bash
JAR=synclite-logger-java/logger/target/synclite-1.0.0.jar
(cd synclite-logger-java/samples \
   && javac -cp ../logger/target/synclite-1.0.0.jar SyncliteSqlitePostgresApp.java)
java -cp "$JAR:synclite-logger-java/samples" SyncliteSqlitePostgresApp
```

### What the sample does

```java
import io.synclite.*;
import java.nio.file.Path;
import java.sql.*;
import java.time.Duration;

public class SyncliteSqlitePostgresApp {
    public static void main(String[] args) throws Exception {
        Path  dbPath  = Path.of("orders.db");
        String pgUrl  = "jdbc:postgresql://localhost:5432/syncdb?user=postgres&password=postgres";
        String schema = "syncschema";

        DestinationOptions dst = DestinationOptions.builder()
                .dstType(DstType.POSTGRES)
                .connectionString(pgUrl)
                .database("syncdb").schema(schema)
                .syncMode(DstSyncMode.CONSOLIDATION).build();

        // One call: local SQLite logger + segment shipper + in-process consolidator -> PostgreSQL.
        SQLite.initialize(dbPath, "orders-device", dst);
        try {
            try (Connection c = DriverManager.getConnection("jdbc:synclite_sqlite:" + dbPath);
                 Statement  s = c.createStatement()) {
                s.execute("DROP TABLE IF EXISTS orders");
                s.execute("CREATE TABLE orders(id INTEGER PRIMARY KEY, item TEXT, qty INTEGER)");
                s.execute("INSERT INTO orders VALUES(1, 'widget', 100)");
            }
            SyncLite.awaitSync(dbPath, Duration.ofSeconds(30));   // wait for PG apply

            try (Connection pg = DriverManager.getConnection(pgUrl, "postgres", "postgres");
                 PreparedStatement ps = pg.prepareStatement(
                     "SELECT row_to_json(t)::text FROM (SELECT * FROM "
                   + schema + ".orders WHERE id = ?) t")) {
                ps.setLong(1, 1);
                try (ResultSet rs = ps.executeQuery()) {
                    System.out.println("[PG] " + (rs.next() ? rs.getString(1) : "no row"));
                }
            }
        } finally { SQLite.closeDevice(dbPath); }
    }
}
```

Full source: [synclite-logger-java/samples/SyncliteSqlitePostgresApp.java](synclite-logger-java/samples/SyncliteSqlitePostgresApp.java).

> **Sample failing?** See [Where does SyncLite put its files?](#where-does-synclite-put-its-files) for the two trace files to check (`<dbPath>.synclite/<dbName>.trace` for logger errors, `<userHome>/synclite/job1/workDir/synclite_<deviceName>_<uuid>/synclite_device.trace` for in-process consolidator errors).

### Same thing in Rust → PostgreSQL

```rust
use synclite::rusqlite::Connection;
use synclite::{DestinationOptions, DeviceType, DstSyncMode, DstType, Result, SyncLiteOptions, Value};
use postgres::{Client, NoTls};

const DB_PATH:        &str = "orders.db";
const DEVICE_NAME:    &str = "orders-device";
const POSTGRES_URL:   &str = "postgresql://postgres:postgres@localhost:5432/syncdb";
const POSTGRES_SCHEMA: &str = "syncschema";

fn main() -> Result<()> {
    // One call: local SQLite logger + segment shipper + in-process consolidator -> PostgreSQL.
    synclite::initialize(
        DeviceType::SQLITE,
        DEVICE_NAME,
        DB_PATH,
        Some(DestinationOptions {
            dst_type: DstType::Postgres,
            dst_connection_string: POSTGRES_URL.into(),
            dst_database: Some("syncdb".into()),
            dst_schema:   Some(POSTGRES_SCHEMA.into()),
            dst_sync_mode: DstSyncMode::Consolidation,
        }),
        SyncLiteOptions::default(),
    )?;

    let mut conn = Connection::open(DB_PATH)?;
    conn.execute("DROP TABLE IF EXISTS orders", &[])?;
    conn.execute(
        "CREATE TABLE orders(id INTEGER PRIMARY KEY, item TEXT, qty INTEGER)",
        &[],
    )?;
    conn.execute(
        "INSERT INTO orders VALUES(?, ?, ?)",
        &[Value::Int(1), Value::Text("widget".into()), Value::Int(100)],
    )?;
    conn.commit()?;

    // Block until the in-flight segment has been applied to PostgreSQL.
    conn.flush()?;
    synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30))?;

    // Read back from PostgreSQL.
    let mut pg = Client::connect(POSTGRES_URL, NoTls)
        .map_err(|e| synclite::Error::Config(format!("{e}")))?;
    let pg_row = pg
        .query_opt(
            &format!(
                "SELECT row_to_json(t)::text FROM (SELECT * FROM {}.orders WHERE id = $1) t",
                POSTGRES_SCHEMA
            ),
            &[&1_i64],
        )
        .map_err(|e| synclite::Error::Config(format!("{e}")))?;
    println!("[PG] {:?}", pg_row.map(|r| r.get::<usize, String>(0)));

    conn.close()?;
    Ok(())
}
```

Run it:

```bash
cd synclite-code-samples/rust
cargo run --example synclite_rusqlite_postgres
```

Full source: [synclite-code-samples/rust/synclite_rusqlite_postgres.rs](synclite-code-samples/rust/synclite_rusqlite_postgres.rs).

SyncLite Runtime (Rust) is the same `cdylib` consumable from Python, Node.js, C/C++, Go, Ruby, and C#. See [Step 4 — Choose Your Use Case](#step-4--choose-your-use-case) for per-language snippets.

---

## Where does SyncLite put its files?

A first-time question every user asks. SyncLite uses **three** roots; only the first one is chosen by your app.

> **Why this layout?** `stageDir/` and `workDir/` deliberately sit under a shared `<userHome>/synclite/job1/` root rather than alongside each DB. That means an embedded-runtime app and the standalone Consolidator WAR can point at the **same** `stageDir/` + `workDir/` with zero file moves — you can switch a deployment from in-process consolidation to the central Consolidator (or vice versa) by changing the call site (`initialize(dbPath, deviceName, dst)` ↔ `initialize(dbPath, conf)`) and starting the Consolidator app. No data migration.

| What lives here | Path | Who picks it | Who reads/writes it |
|---|---|---|---|
| Your local DB file (e.g. `orders.db`) | `<dbPath>` — wherever your app calls `initialize(dbPath, ...)` | **You** | Your app + the SyncLite logger |
| Per-DB logger trace + trigger files (`reinitialize.<dev>`, `pause_sync.<dev>`, …) | `<dbPath>.synclite/` (sibling of the DB file, e.g. `orders.db.synclite/orders.db.trace`) | SyncLite (derived from `dbPath`) | Logger writes the trace; you drop trigger files here |
| Outbound log segments (in-flight + retained) | `<userHome>/synclite/job1/stageDir/synclite_<deviceName>_<uuid>/` | SyncLite (default; overridable via `local-data-stage-directory` in `synclite.conf`) | Logger writes; shipper / Consolidator reads |
| In-process consolidator state + `synclite_device.trace` | `<userHome>/synclite/job1/workDir/synclite_<deviceName>_<uuid>/` | SyncLite (default; overridable via `work-dir` in `synclite.conf`) | In-process or standalone Consolidator |
| Standalone Consolidator global trace (`synclite_consolidator.trace`) | `<workDir>/synclite_consolidator.trace` | Consolidator app | **Standalone Consolidator only** — the embedded runtime never writes this |

**Two traces to know about when something breaks:**

1. `<dbPath>.synclite/<dbName>.trace` — logger-side errors (config parse failures, log-write errors, schema-evolution problems on the local DB).
2. `<userHome>/synclite/job1/workDir/synclite_<deviceName>_<uuid>/synclite_device.trace` — in-process consolidator errors (destination auth failures, missing destination schema, DDL conflicts, retry attempts).

For a sample whose DB is `orders.db` and `deviceName = "orders-device"`, the full layout on disk looks like:

```text
<your app's cwd>/
+-- orders.db                                 # your local SQLite/DuckDB/... DB
+-- orders.db.synclite/
    +-- orders.db.trace                       # logger trace
    +-- reinitialize.orders-device            # (optional) trigger files you drop here
    +-- pause_sync.orders-device              # (optional)

<userHome>/synclite/job1/
+-- stageDir/
|   +-- synclite_orders-device_<uuid>/        # outbound .sqllog segments
+-- workDir/
    +-- synclite_orders-device_<uuid>/
        +-- synclite_device.trace             # in-process consolidator trace
        +-- ... (consolidator metadata)
```

To relocate these roots, set `local-data-stage-directory` and `work-dir` in `synclite.conf` and pass the conf to `initialize(dbPath, conf)`.

---

## Step 3 — (Optional) Deploy the Full Platform

Skip this step if all you need is the embedded runtime. Use it when you want the central **Consolidator + DBReader + QReader + Job Monitor + Sample Web App** running as services.

### Native (Windows / Linux / macOS)

```bash
cd target/synclite-platform-1.0.0/bin/

# First run: downloads Tomcat + JDK, deploys all WARs
./deploy.sh          # Linux/macOS
deploy.bat           # Windows

# Start Tomcat and all SyncLite apps
./start.sh           # Linux/macOS
start.bat            # Windows
```

### Docker (all-in-one)

```bash
cd target/synclite-platform-1.0.0/bin/

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

### Try the Sample Web App

The sample web app embeds SyncLite (Java) in **logger-only** mode — it produces `.sqllog` segments to the staging storage and relies on the standalone Consolidator WAR (configured below) to apply them to the destination. It does **not** use the in-process consolidator path.

1. Open [http://localhost:8080/synclite-consolidator](http://localhost:8080/synclite-consolidator) and configure a destination database (e.g., the PostgreSQL container you started in Step 2).
2. Open [http://localhost:8080/synclite-sample-app](http://localhost:8080/synclite-sample-app)
3. Create a device, run SQL workloads, and watch live sync to your configured destination — all from your browser.

---

## Step 4 — Choose Your Use Case

### 🦀 Rust — Pure Native Library (NEW)

The entire SyncLite Runtime is now packaged as a single embeddable Rust
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

    // Offline-first SQLite device that syncs every change to PostgreSQL.
    synclite::initialize(
        DeviceType::SQLITE,
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

    // Demo only: await_sync is used here to make the sample deterministic.
    // In production, sync runs in the background after commit/flush.
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

**Supported devices:** `Sqlite` (SQL + STORE + STREAMING), `Duckdb` (SQL + STORE).
**Supported destinations:** `Sqlite`, `Duckdb`, `Postgres`.

**Device encryption:** not supported in SyncLite Runtime (Rust) yet.

**Need to reset a device?** `synclite::reinitialize(db_path, clean_destination)`
wipes per-device local state and the device's destination metadata so the next
`synclite::initialize` re-seeds from scratch under the same UUID and device name.
With `clean_destination=true` in `REPLICATION` mode the user tables owned by
this device are dropped too; in `CONSOLIDATION` mode dropping is a no-op so
sibling devices on a shared destination stay safe. Drop a
`reinitialize.<device-name>` or
`reinitialize_with_clean_destination.<device-name>` file alongside the database
to trigger a reinit on the next bring-up without writing code.

**Need to pause sync?** `synclite::pause_sync(db_path)` halts only the
consolidator's apply step — the logger keeps appending segments and the shipper
keeps publishing them locally. Call `synclite::resume_sync(db_path)` to drain
the queue. State is persisted in a sentinel file, and a
`pause_sync.<device-name>` / `resume_sync.<device-name>` trigger-file pair
toggles state on the next `initialize` without writing code.

**Inspecting sync state.** `synclite::sync_status(db_path)` returns the run
state (`NotInitialized` / `Paused` / `Running`) plus the consolidator's last
heartbeat row. `synclite::sync_statistics(db_path)` reports segments-applied,
ops, txns, bytes, and the last consolidated commit id. `synclite::sync_latency(db_path)`
returns `source - applied` as wall-clock milliseconds (every `commit_id` is a
`System.currentTimeMillis()` value); `-1` means the applied side is unknown
(destination unreachable, consolidator not running yet, etc.).

Runnable samples live in [`synclite-code-samples/rust/`](synclite-code-samples/rust/):

```sh
cd synclite-code-samples/rust
cargo run --example synclite_rusqlite
cargo run --example synclite_duckdb_store
cargo run --example synclite_streaming
```

---

### ☕ Java — Embedded Runtime (NEW)

The Java SDK ships as a **single jar** (`synclite-<version>.jar`) that already bundles
logger + shipper + in-process consolidator (via a JNI-loaded native engine inside the jar).
Drop it in, call `SQLite.initialize(dbPath, deviceName, destinationOptions)`, and your JVM app
syncs to PostgreSQL (or SQLite/DuckDB) in the background. No separate Consolidator WAR to
deploy.

```java
import io.synclite.*;
import java.nio.file.Path;
import java.sql.*;
import java.time.Duration;

public class App {
    public static void main(String[] args) throws Exception {
        Path dbPath = Path.of("orders.db");
        DestinationOptions dst = DestinationOptions.builder()
                .dstType(DstType.POSTGRES)
                .connectionString("jdbc:postgresql://localhost:5432/syncdb?user=postgres&password=postgres")
                .database("syncdb")
                .schema("syncschema")
                .syncMode(DstSyncMode.CONSOLIDATION)
                .build();

        // One call wires up the local logger, the segment shipper, and the
        // embedded consolidator that drains into PostgreSQL.
        SQLite.initialize(dbPath, "orders-device", dst);
        try {
            try (Connection conn = DriverManager.getConnection("jdbc:synclite_sqlite:" + dbPath);
                 Statement s = conn.createStatement()) {
                s.execute("CREATE TABLE IF NOT EXISTS orders(id INT, item TEXT, qty INT)");
                s.execute("INSERT INTO orders VALUES(1, 'widget', 100)");
            }
            // Block until the in-flight segment has been applied to PostgreSQL.
            SyncLite.awaitSync(dbPath, Duration.ofSeconds(30));
        } finally {
            SQLite.closeDevice(dbPath);
        }
    }
}
```

Run with the SyncLite jar on the classpath (no extra fat jar — the in-process consolidator is already bundled):

```sh
java -cp synclite-logger-java/logger/target/synclite-1.0.0.jar:. App
```

**Section A below** describes the *logger-only* mode (same `synclite-<version>.jar`, just
called via `initialize(dbPath, conf)` instead of `initialize(dbPath, deviceName, dst)`)
which works with a separate standalone Consolidator WAR — useful when many devices fan in
to one central pipeline.

Runnable embedded-runtime sample: [`synclite-logger-java/samples/SyncliteSqlitePostgresApp.java`](synclite-logger-java/samples/SyncliteSqlitePostgresApp.java).

---

### A. Edge / Desktop App with Embedded Database (Java)

Add `synclite-<version>.jar` to your classpath, then:

```java
import io.synclite.*;
import java.nio.file.Path;
import java.sql.*;

Path dbDir  = Path.of(System.getProperty("user.home"), "synclite", "db");
Path dbPath = dbDir.resolve("myapp.db");
Path conf   = dbDir.resolve("synclite.conf");

// Initialize with SQLite (replace SQLite / synclite_sqlite with DuckDB, Derby, H2, HyperSQL as needed)
Class.forName("io.synclite.SQLite");
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
import io.synclite.SQLiteStore;
import io.synclite.SyncLiteStore;

Class.forName("io.synclite.SQLiteStore");
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


---

### G. SyncLite DB — Local-First HTTP/JSON Database (Any Language)

SyncLite DB is a local-first, sync-enabled database server. The recommended way to run it is as a web application (WAR) with a browser-based GUI:

1. **Deploy the WAR:**  
   - Copy `synclite-db-oss.war` (from `tools/synclite-db/` or `root/web/target/`) into the `webapps/` directory of your Apache Tomcat server.
   - Start Tomcat (see platform or Tomcat documentation).

2. **Access the Web UI:**  
   - Open your browser and go to:  
     `http://localhost:8080/synclite-db`  
     (Adjust port if your Tomcat uses a different one.)

3. **Configure & Start:**  
   - Use the web interface to configure databases, logger options, and start/stop the SyncLite DB server.
   - All management, monitoring, and job setup is now available via the GUI.

> **Note:** The legacy CLI scripts (`synclite-db.sh` / `.bat`) are still available for advanced/manual use:

```bash
# Linux / macOS
./tools/synclite-db/synclite-db.sh --config synclite_db.conf
# Windows
tools\synclite-db\synclite-db.bat --config synclite_db.conf
```

Once running, you can send plain HTTP POST requests — no SDK needed. Example (Python):

```python
import requests

BASE = "http://localhost:5555/synclite"

# Initialize
requests.post(BASE, json={
    "db-type": "SQLITE",
    "db-name": "myapp",
    "synclite-logger-options": {
        "local-data-stage-directory": "/tmp/stage"
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


---

## Configure the Consolidator

To enable sync from the sample app or any SyncLite device, you must configure the SyncLite Consolidator:

1. Open [http://localhost:8080/synclite-consolidator](http://localhost:8080/synclite-consolidator)
2. Click **Configure Job** and set the staging storage path (e.g., a local directory, or SFTP/S3/MinIO/Kafka URL).
3. Add a **Destination** — choose from PostgreSQL, MySQL, MariaDB, SQL Server, Oracle, Amazon Redshift, ClickHouse, MongoDB, Apache Iceberg, Delta Lake, Apache Hudi, Parquet/CSV, and more.
4. Start the job. The dashboard will show per-device replication lag, throughput, and errors in real time.

---

## Staging Storage Options

SyncLite supports a variety of staging backends for log shipping:

- **Local/NFS:** Set `local-data-stage-directory` in your `synclite.conf` or SyncLite DB configuration.
- **SFTP:** Use the provided helper script:  
    `bin/stage/sftp/docker-deploy.sh`
- **MinIO:**  
    `bin/stage/minio/docker-deploy.sh`
- **Amazon S3:**  
    Configure `s3-*` properties in your config file.
- **Apache Kafka:**  
    Configure `kafka-*` properties in your config file.
- **Microsoft OneDrive:**  
    Configure `onedrive-*` properties in your config file.
- **Google Drive:**  
    Configure `gdrive-*` properties in your config file.

> See the [full documentation](https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md) for advanced staging and destination configuration.

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
| Full platform documentation | https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md |
| Website | https://www.synclite.io |
| GitHub repository | https://github.com/syncliteio/SyncLite |
| Community | https://github.com/syncliteio/SyncLite/issues |
| Patent | https://www.synclite.io/about |
| Contribution guide | [CONTRIBUTING.md](CONTRIBUTING.md) |
| License (Apache 2.0) | [LICENSE](LICENSE) |

---

← Back to the [platform README](README.md)
