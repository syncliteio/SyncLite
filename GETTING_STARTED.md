# Getting Started with SyncLite

**Your app should never wait on a network call to write data.** Embed a real local database, get full ACID transactions at native speed, and let SyncLite replicate every committed write transactionally to your destination automatically.

-> [README](README.md) - [Full Documentation](https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md) - [Website](https://www.synclite.io)


---

## Step 1 - Add the dependency

```bash
pip install synclite                     # Python - self-contained, batteries included
```
```bash
cargo add synclite-rs                    # Rust - cdylib also usable from C/C++, Go, Node, Ruby, C#
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

The Python wheel and Java jar are **self-contained** - they bundle the native runtime, DuckDB, and the PostgreSQL driver. `pip install` is genuinely all you need on Windows, Linux, and macOS.

---

## Step 2 - Write your first syncing app

### Python

```python
import synclite as sl

DB_PATH  = "sampledevice.db"
POSTGRES = "postgresql://postgres:postgres@localhost:5432/syncdb"
DB       = "syncdb"
SCHEMA   = "syncschema"

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
conn.execute("UPDATE orders SET qty = ? WHERE id = ?", [150, 1])
conn.commit()

conn.flush()                          # ensure pending writes are shipped before process exits
sl.await_sync(DB_PATH, 30.0)          # optional: block until PostgreSQL confirms apply
conn.close()
```

Full sample: [`synclite-code-samples/python/synclite_rusqlite_postgres.py`](synclite-code-samples/python/synclite_rusqlite_postgres.py)

---

### Java

```java
import io.synclite.*;
import java.nio.file.Path;
import java.sql.*;
import java.time.Duration;

private static final Path   DB_PATH         = Path.of("sampledevice.db");
private static final String DEVICE_NAME     = "sampledevice";
private static final String POSTGRES_URL    =
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
    s.execute("UPDATE orders SET qty = 150 WHERE id = 1");
}

SyncLite.awaitSync(DB_PATH, Duration.ofSeconds(30)); // optional: block until PostgreSQL confirms apply
SQLite.closeDevice(DB_PATH);
```

Full sample: [`synclite-code-samples/java/SyncliteSqlitePostgresApp.java`](synclite-code-samples/java/SyncliteSqlitePostgresApp.java)

> **Something failing?** Check `<dbPath>.synclite/<dbName>.trace` (logger errors) and
> `<userHome>/synclite/job1/workDir/synclite_<deviceName>_<uuid>/synclite_device.trace` (consolidator errors).

---

### Rust

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
conn.execute("UPDATE orders SET qty = ? WHERE id = ?",
    &[Value::Int(150), Value::Int(1)])?;
conn.commit()?;

conn.flush()?;  // ensure pending writes are shipped before process exits
synclite::await_sync(DB_PATH, std::time::Duration::from_secs(30))?; // optional: block until PG confirms
conn.close()?;
```

Full sample: [`synclite-code-samples/rust/synclite_rusqlite_postgres.rs`](synclite-code-samples/rust/synclite_rusqlite_postgres.rs)

The Rust crate is also a `cdylib` - embeddable from **Python, Node.js, C/C++, Go, Ruby, C#**.

---

## Where does SyncLite put its files?

SyncLite uses **three** roots on disk; only the first one is chosen by your app.

| What lives here | Default path | Who picks it |
|---|---|---|
| Your local DB file | `<dbPath>` - wherever your app calls `initialize(dbPath, ...)` | **You** |
| Logger trace + trigger files | `<dbPath>.synclite/` (e.g. `orders.db.synclite/orders.db.trace`) | SyncLite (derived from `dbPath`) |
| Outbound log segments | `<userHome>/synclite/job1/stageDir/synclite_<deviceName>_<uuid>/` | SyncLite (overridable via `local-data-stage-directory` in `synclite.conf`) |
| In-process consolidator state + trace | `<userHome>/synclite/job1/workDir/synclite_<deviceName>_<uuid>/` | SyncLite (overridable via `work-dir` in `synclite.conf`) |

**Two trace files to check when something breaks:**
1. `<dbPath>.synclite/<dbName>.trace` - logger errors (config, log-write, schema-evolution).
2. `<userHome>/synclite/job1/workDir/synclite_<deviceName>_<uuid>/synclite_device.trace` - consolidator errors (destination auth, DDL conflicts, retries).

For `orders.db` / `device_name = "sampledevice"`:

```text
<cwd>/
+-- orders.db                                    # your local DB
+-- orders.db.synclite/
    +-- orders.db.trace                          # logger trace

<userHome>/synclite/job1/
+-- stageDir/
|   +-- synclite_sampledevice_<uuid>/            # outbound .sqllog segments
+-- workDir/
    +-- synclite_sampledevice_<uuid>/
        +-- synclite_device.trace                # in-process consolidator trace
```

> **Why this layout?** `stageDir/` and `workDir/` live under a shared `job1/` root so an embedded-runtime app and the standalone Consolidator WAR can point at the **same** directories with no file moves. Switching between in-process and central consolidation is a one-line code change.

---

## Write styles - SQL, Store, or Stream

A "device" is a logical embedded DB that the runtime owns end-to-end. Pick the API that fits your code:

| API | Best for | Device types |
|---|---|---|
| **SQL** | Full JDBC/SQL, JOINs, multi-statement txns, ad-hoc DDL | `SQLite`, `DuckDB`, `Derby`, `H2`, `HyperSQL` |
| **Store** (`SyncLiteStore`) | Simple CRUD, automatic schema evolution, highest consolidation throughput | `SQLITE_STORE`, `DUCKDB_STORE`, ... |
| **Stream** (`SyncLiteStream`) | High-throughput append-only event ingestion, no UPDATE/DELETE needed | `STREAMING` |

> For a new app, `SQLITE_STORE` is usually the fastest *and* simplest starting point.

### Store API (Java)

```java
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
```

### Stream API (Java)

```java
try (SyncLiteStream stream = SyncLiteStream.open(dbPath)) {
    stream.createTable("events", new LinkedHashMap<>(Map.of(
        "ts", "BIGINT", "event_type", "TEXT", "user_id", "TEXT"
    )));
    stream.insert("events", Map.of(
        "ts", System.currentTimeMillis(), "event_type", "SIGNUP", "user_id", "u1"));
    stream.insertBatch("events", List.of(
        Map.of("ts", System.currentTimeMillis(), "event_type", "VIEW",     "user_id", "u2"),
        Map.of("ts", System.currentTimeMillis(), "event_type", "PURCHASE", "user_id", "u3")
    ));
}
```

### Jedis (Redis-compatible) API (Java)

`io.synclite.Jedis` is a drop-in subclass of `redis.clients.jedis.Jedis`. Every write is durably committed to a `SQLITE_STORE` device before being forwarded to Redis.

```java
try (Jedis jedis = Jedis.builder(dbPath, conf, "cache-device")
        .host("localhost").port(6379).build()) {
    jedis.set("user:1:name", "Alice");
    jedis.hset("session:42", Map.of("token", "abc123", "status", "active"));
    jedis.rpush("queue", "job-1", "job-2");
}
```

---

## Deploy the full platform (optional)

Skip this if you only need the embedded runtime. Use it when you want the **central Consolidator + DBReader + QReader + Job Monitor** running as services.

> **No build required.** Download the latest **`synclite-platform-<version>.zip`** from [GitHub Releases](https://github.com/syncliteio/SyncLite/releases), unzip it, and run from the extracted folder.

```bash
cd bin/
./deploy.sh      # or deploy.bat on Windows   (downloads Tomcat + JDK, deploys all WARs)
./start.sh       # or start.bat on Windows    (starts Tomcat + every SyncLite app)
```

```bash
# Docker all-in-one (edit STAGE and DST at the top of docker-deploy.sh first)
./docker-deploy.sh
./docker-start.sh
```

| URL | App |
|---|---|
| http://localhost:8080/synclite-consolidator | Configure consolidation jobs + destinations |
| http://localhost:8080/synclite-sample-app | Create devices, run SQL, see live sync |
| http://localhost:8080/synclite-dbreader | Database ETL/replication pipelines |
| http://localhost:8080/synclite-qreader | IoT / MQTT ingestion |
| http://localhost:8080/synclite-jobmonitor | Schedule + monitor all jobs |

> WARNING: Docker helper scripts use default credentials. Change usernames, passwords, and enable TLS before any production use.

### Tool combos to try

**Sample Web App -> Consolidator** (no external source DB)
1. Open [synclite-consolidator](http://localhost:8080/synclite-consolidator) -> configure **staging** + **destination** -> start job.
2. Open [synclite-sample-app](http://localhost:8080/synclite-sample-app) -> create a device pointing at the **same** staging location.
3. Run SQL and watch rows land in your destination live.

**DBReader -> Consolidator** (database -> database replication/ETL)
1. Configure Consolidator (staging + destination) and start.
2. Open [synclite-dbreader](http://localhost:8080/synclite-dbreader) -> configure source DB -> same staging location.
3. Start DBReader. Initial snapshot + incremental changes flow to the destination.

**SyncLite DB -> Consolidator** (any language via HTTP/JSON)
1. Start the consolidation job (staging + destination).
2. Deploy `synclite-db-1.0.0.war` (from `tools/synclite-db/`) and point it at the same staging location.
3. POST SQL as JSON from any language - see [synclite-db/sdk-source/](synclite-db/sdk-source/) for Java, Python, C#, Go, Node.js, Ruby, Rust, C++ samples.

**QReader -> Consolidator** (IoT / MQTT)
1. Start the consolidation job.
2. Open [synclite-qreader](http://localhost:8080/synclite-qreader) -> configure broker + topic-to-table mapping -> same staging location.
3. Publish MQTT messages; parsed payloads flow to the destination.

---

## Staging storage options

Configure `local-data-stage-directory` in `synclite.conf` for local/NFS staging. For remote staging use the matching Docker helpers:

```bash
bin/stage/sftp/docker-deploy.sh     # SFTP server
bin/stage/minio/docker-deploy.sh    # MinIO object storage
```

Supported: **local FS, NFS, SFTP, Amazon S3, MinIO, Apache Kafka, Microsoft OneDrive, Google Drive**.

---

## Destinations supported

| Category | Systems |
|---|---|
| Relational | PostgreSQL, MySQL, MariaDB, SQL Server, Oracle, SQLite, DuckDB, Derby, H2, HyperSQL |
| Data warehouses | Amazon Redshift, ClickHouse |
| Data lakes | Apache Iceberg, Delta Lake, Apache Hudi |
| NoSQL | MongoDB |
| File / Object | Apache Parquet, CSV |

---

## Build from source

> **Most users don't need this.** Use `pip install synclite` / `cargo add synclite-rs` / the Maven coordinate to embed the runtime. Download the [release zip](https://github.com/syncliteio/SyncLite/releases) to try the tools. Build from source only for development or customization.

> **Architecture support.** SyncLite is **64-bit only** - `x86_64` and `aarch64` on Windows / Linux / macOS. 32-bit hosts are not supported because SyncLite Runtime (Rust) depends on the DuckDB engine, which requires a 64-bit host.

```bash
git clone --recurse-submodules https://github.com/syncliteio/SyncLite.git SyncLite
cd SyncLite
```

### Prerequisites

**Java-only build** (no Rust toolchain required):
- Java 25
- Apache Maven 3.8.6+

**Full build (including Rust runtime and Python wheel):**
- All of the above, plus:
- Rust toolchain 1.86.0 + Cargo 1.86.0 (bundled with Rust)
- **Native C/C++ toolchain (system linker):**
  - **Windows**: Microsoft C++ Build Tools (`link.exe`) - install from https://visualstudio.microsoft.com/visual-cpp-build-tools/ and select the **"Desktop development with C++"** workload.
  - **Linux**: `build-essential` + `cmake` - e.g. `sudo apt install build-essential pkg-config cmake`
  - **macOS**: Xcode Command Line Tools - `xcode-select --install`
- [`cargo-zigbuild`](https://github.com/rust-cross/cargo-zigbuild) and [Zig](https://ziglang.org/download/) on `PATH` (for cross-compilation)
- Rust standard libraries for Linux x86_64 and aarch64:
  ```bash
  cargo install cargo-zigbuild
  rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu
  # zig must be on PATH - download from https://ziglang.org/download/
  ```
- **Python 3.8+ and [`maturin`](https://www.maturin.rs/)** (for the host-platform Python wheel):
  ```bash
  python -m pip install maturin
  # Windows: pip install delvewheel
  # Linux:   pip install auditwheel
  # macOS:   pip install delocate
  ```
  Skip with `-DskipPythonWheel=true` (also skipped automatically by `-DskipNonJavaLoggers=true`).

### Build flavors

| # | Flavor | What it produces |
|---|---|---|
| 1 | **Full platform** (default) | `target/synclite-platform-<rev>.zip` - Tomcat scripts + WARs + tools + samples + multi-arch native runtime |
| 2 | **Full platform, Java-only** | Same as #1 but no `lib/native/` (no Rust toolchain required) |
| 3 | **Runtime** (recommended for app developers) | `target/synclite-runtime-<rev>.zip` - slim zip with `lib/java/` (synclite jar) + multi-arch `lib/native/` (Rust cdylibs) + cross-language `sample-apps/{cpp,java,python,rust}` |

```bash
# 1. Full platform (default)
mvn -Drevision=1.0.0 clean install

# 2. Full platform, Java-only (no Rust toolchain required)
mvn -Drevision=1.0.0 -DskipNonJavaLoggers=true clean install

# 3. Runtime only - slim embeddable zip (recommended for app developers)
mvn -Drevision=1.0.0 -DruntimeOnly=true clean install

# Fastest build - skip zig cross-compilation and tests
mvn -Drevision=1.0.0 -DruntimeOnly=true -DskipRustCrossCompile=true -DskipTests clean install
```

> To build only a single subproject: `cd synclite-logger-java && mvn install` or `cd synclite-logger-rust && cargo build --workspace --release`.

> The `bin/deploy.sh` / `bin/deploy.bat` scripts download Apache Tomcat 9.0.117 and OpenJDK 25 automatically - no manual JDK/Tomcat installation needed.

---

## What's next

| Resource | Link |
|---|---|
| Full Documentation | https://github.com/syncliteio/SyncLite/blob/main/DOCUMENTATION.md |
| README | [README.md](README.md) |
| Code samples (all languages) | [synclite-code-samples/](synclite-code-samples/README.md) |
| Website | https://www.synclite.io |
| Issues / Community | https://github.com/syncliteio/SyncLite/issues |
| Contributing | [CONTRIBUTING.md](CONTRIBUTING.md) |
| License (Apache 2.0) | [LICENSE](LICENSE) |

