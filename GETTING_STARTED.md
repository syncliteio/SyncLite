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
- **Pick your language.** First-class **Java** (jar) and **Rust** (crate) runtimes; the Rust runtime is embeddable from **Python, Node.js, C/C++, Go, Ruby, C#** via a single `cdylib`.
- **Pick your local DB.** SQLite, DuckDB, Apache Derby, H2, HyperSQL — all behind the same APIs.
- **Pick your write style.** Plain **JDBC / SQL**, a typed **Store CRUD** API (`insert` / `update` / `delete` / `selectAll`), a fluent **Stream** append-only API, or a drop-in **Jedis** subclass for Redis users.
- **Sync is just config.** Point the runtime at a destination and writes start flowing — no separate CDC tool, no Kafka, no replication agent.

---

## Runtime first, tools on top

SyncLite ships as two things:

1. **The Runtime** — what your application embeds. This is the core of the project: a small library that owns the local DB, the log, the shipper, and (in the full-runtime jar / Rust crate) the in-process consolidator that pushes data to destinations.
2. **Optional tooling** — webapps and CLIs built **on top of** the same runtime, for teams who want centralized ops, scheduled ETL jobs, IoT ingest, or end-to-end test harnesses. None of them are required to use the runtime in your code.

If you're a developer building an app, you only need group 1. If you're standing up a data platform, group 2 is there when you need it.

### Components

**Embeddable runtime — link it into your app**

| Component | What It Does |
|---|---|
| **SyncLite for Java** (`synclite-<version>.jar`) | One jar = JDBC / Store / Stream APIs + logger + shipper + (optional) in-process consolidator via bundled `synclite_jni` native. |
| **SyncLite Rust Runtime** | Same runtime in Rust as a single `cdylib`. Consumable from Rust, Python, Node.js, C/C++, Go, Ruby, C#. |

**Optional tooling — built on top of the runtime**

| Component | What It Does |
|---|---|
| **SyncLite DB** | Wraps the runtime as a tiny local-first HTTP/JSON service for any language that doesn't (yet) embed the native lib. |
| **SyncLite Client** | Interactive CLI for inspecting and querying SyncLite devices. |
| **SyncLite Consolidator** | Standalone consolidation service for the central topology — accepts log segments from many embedded devices / edge applications and applies them to destinations. |
| **SyncLite DBReader** | Database ETL / replication / migration jobs (source DB → SyncLite devices → destinations). |
| **SyncLite QReader** | IoT MQTT connector (Eclipse Paho; works with any MQTT v3.1 broker). |
| **SyncLite Job Monitor** | Unified job management and scheduling UI for DBReader / QReader / Consolidator jobs. |
| **SyncLite Validator** | End-to-end integration test harness. |
| **Sample Web App** | JSP/Servlet demo showing the Java runtime embedded inside a real web app. |

---

## Step 1 — Build SyncLite

> **Architecture support.** SyncLite is **64-bit only** — `x86_64` and `aarch64` on Windows / Linux / macOS. 32-bit hosts are not supported because the embedded Rust runtime depends on the DuckDB engine, which requires a 64-bit host.

### Prerequisites (Java-only build)

| Requirement | Version |
|---|---|
| Java | 25 |
| Apache Maven | 3.8.6+ |
| Git | any recent version |

### Additional prerequisites (build all loggers including the Rust runtime)

| Requirement | Version |
|---|---|
| Rust toolchain (`rustup`, `cargo`) | 1.86.0 |
| [`cargo-zigbuild`](https://github.com/rust-cross/cargo-zigbuild) | latest |
| [Zig](https://ziglang.org/download/) compiler on `PATH` | latest stable |
| Rust standard libraries for Linux x86_64 and aarch64 | — |

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
mvn -Drevision=oss clean install

# 2. Full platform, Java-only — same Tomcat platform zip as #1 but no lib/native/ (no Rust toolchain required)
mvn -Drevision=oss -DskipNonJavaLoggers=true clean install

# 3. Runtime — slim embeddable zip: synclite jar + multi-arch native cdylibs + sample-apps/{cpp,java,python,rust}
mvn -Drevision=oss -DruntimeOnly=true clean install
```

> **What `-DruntimeOnly=true` does:** activates a Maven profile that reduces the reactor to just the `synclite-logger-java/logger` module and switches the assembly from the full `synclite-platform-<rev>.zip` to the slim `synclite-runtime-<rev>.zip`. Skips the consolidator, dbreader, qreader, job-monitor, validator, sample-web-app, db, and client modules.

> **What `-DskipNonJavaLoggers=true` does:** skips all parent-pom Rust executions (host build + Linux x86_64 + Linux aarch64) and excludes `lib/native/` from the assembly. It also auto-activates `-DskipRustCrossCompile=true` and `-DskipRustTests=true`. Use whenever you don't have a Rust toolchain on the build host.

### Build accelerators

These switches combine with any flavor above:

- **`-DskipTests`** — skip JUnit + Rust device-integration tests.
- **`-DskipRustCrossCompile=true`** — skip the two Linux cross-compile cargo executions (`x86_64-unknown-linux-gnu` + `aarch64-unknown-linux-gnu`). Use on hosts without `cargo-zigbuild` + `zig` on `PATH`; the host-arch cdylib is still built. Only relevant for flavors #1 and #3 (flavor #2 already skips all Rust).

```bash
# Fastest full platform build (skips all tests)
mvn -Drevision=oss -DskipTests clean install

# Fastest runtime build on a host without zig — host-arch cdylib only, no Linux cross-compile, no tests
mvn -Drevision=oss -DruntimeOnly=true -DskipRustCrossCompile=true -DskipTests clean install
```

### Build the Rust runtime directly (no Maven packaging)

If you only need the Rust crate / cdylib for embedding in Rust, Python, Node.js, C/C++, Go, Ruby, or C#, you can skip Maven entirely and build the Rust workspace directly:

```bash
cd synclite-logger-rust
cargo build --workspace
```

### Release structure

The **runtime** flavor (#3) assembles under `SyncLite/target/synclite-runtime-oss/`:

```
synclite-runtime-oss/
+-- lib/
|   +-- java/
|   |   +-- synclite-<version>.jar                    # Add to your app classpath
|   |   +-- synclite.conf                             # Default logger configuration
|   +-- native/                                       # Multi-arch Rust runtime cdylibs
|   |   +-- libsynclite_<version>.dll                 # Windows host build
|   |   +-- libsynclite_<version>.lib                 # Windows import library
|   |   +-- libsynclite_<version>_linux_x86_64.so     # cross-compiled (omitted if -DskipRustCrossCompile=true)
|   |   +-- libsynclite_<version>_linux_aarch64.so    # cross-compiled (omitted if -DskipRustCrossCompile=true)
|   |   +-- libsynclite_<version>.dylib               # only if built on macOS
|   |   +-- synclite.conf
+-- sample-apps/                                      # Language samples: cpp, java, python, rust
+-- LICENSE
+-- synclite_platform_version.txt
```

The **full platform** flavors (#1 and #2) assemble under `SyncLite/target/synclite-platform-oss/`:

```
synclite-platform-oss/
+-- bin/                                              # deploy / start / stop, Docker helpers
+-- lib/                                              # Same as runtime zip above
|   +-- java/
|   +-- native/                                       # Present in flavor #1 only
+-- tools/                                            # synclite-db, dbreader, qreader, job-monitor, validator
+-- sample-apps/                                      # Java, Python, and JSP/Servlet samples
```

---

## Step 2 — Try the Embedded Runtime (Java → PostgreSQL)

The fastest way to see SyncLite in action is to drop the single jar into a Java app and sync writes straight into PostgreSQL — no Tomcat, no separate Consolidator service.

### Spin up a local PostgreSQL destination

Use the bundled Docker helper:

```bash
cd target/synclite-platform-oss/bin/dst/postgresql/
./docker-deploy.sh    # starts PostgreSQL on localhost:5432 (user: postgres / pwd: postgres)
```

Or use any existing PostgreSQL with a database `syncdb` and schema `syncschema`.

### Run the bundled sample

```bash
JAR=synclite-logger-java/logger/target/synclite-oss.jar
(cd synclite-logger-java/samples \
   && javac -cp ../logger/target/synclite-oss.jar SyncliteSqlitePostgresApp.java)
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
        String pgUrl  = "jdbc:postgresql://localhost:5432/syncdb";
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

### Same thing in Rust → PostgreSQL

```bash
cd synclite-code-samples/synclite-runtime/rust
cargo run --example synclite_rusqlite_postgres
```

The Rust runtime is the same `cdylib` consumable from Python, Node.js, C/C++, Go, Ruby, and C#. See [Step 4 — Choose Your Use Case](#step-4--choose-your-use-case) for per-language snippets.

---

## Step 3 — (Optional) Deploy the Full Platform

Skip this step if all you need is the embedded runtime. Use it when you want the central **Consolidator + DBReader + QReader + Job Monitor + Sample Web App** running as services.

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

### Try the Sample Web App

The sample web app shows the Java runtime embedded inside a real JSP/Servlet app, with live sync to a destination configured in the Consolidator.

1. Open [http://localhost:8080/synclite-consolidator](http://localhost:8080/synclite-consolidator) and configure a destination database (e.g., the PostgreSQL container you started in Step 2).
2. Open [http://localhost:8080/synclite-sample-app](http://localhost:8080/synclite-sample-app)
3. Create a device, run SQL workloads, and watch live sync to your configured destination — all from your browser.

---

## Step 4 — Choose Your Use Case

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

**Device encryption:** not supported in the Rust runtime yet.

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

Runnable samples live in [`synclite-code-samples/synclite-runtime/rust/`](synclite-code-samples/synclite-runtime/rust/):

```sh
cd synclite-code-samples/synclite-runtime/rust
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
                .connectionString("jdbc:postgresql://localhost:5432/syncdb")
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
java -cp synclite-logger-java/logger/target/synclite-oss.jar:. App
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
