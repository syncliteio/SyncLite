# SyncLite Runtime Samples

One end-to-end sample per language, each demonstrating the same story: a local SQLite database whose every change — DML **and** schema evolution — is replicated to PostgreSQL by the in-process consolidator.

| Language | Sample | Folder README |
|---|---|---|
| Java   | [`SyncliteSqlitePostgresApp.java`](java/SyncliteSqlitePostgresApp.java)            | [java/README.md](java/README.md) |
| Python | [`synclite_rusqlite_postgres.py`](python/synclite_rusqlite_postgres.py)            | [python/README.md](python/README.md) |
| Rust   | [`synclite_rusqlite_postgres.rs`](rust/synclite_rusqlite_postgres.rs)              | [rust/README.md](rust/README.md) |
| C++    | [`synclite_rusqlite_postgres.cpp`](cpp/synclite_rusqlite_postgres.cpp)             | [cpp/README.md](cpp/README.md) |

## Install the SyncLite runtime (v1.0.0)

Each sample can run against the **published** SyncLite runtime for its language — no repo checkout required. Grab the one for your stack, then follow that folder's README:

| Language | Install | Registry |
|---|---|---|
| Python | `pip install synclite==1.0.0` | [PyPI](https://pypi.org/project/synclite/) |
| Rust   | `cargo add synclite@1.0.0` (or `synclite = "1.0.0"` in `Cargo.toml`) | [crates.io](https://crates.io/crates/synclite) |
| Java   | `io.synclite:synclite:1.0.0` (Maven / Gradle — see [java/README.md](java/README.md#quickest-start--add-the-maven-dependency)) | Maven Central |
| C++    | Link the native `synclite` cdylib (built from the `synclite` crate / bundled SDK — see [cpp/README.md](cpp/README.md)) | crates.io / release zip |

The Python wheel and Java jar are self-contained (they bundle their native runtime + DuckDB). The Rust crate and C++ binding compile the native DuckDB dependency, so a C/C++ toolchain + CMake are required. Prefer a fully offline flow? Every folder README also documents running straight from an extracted release zip.

All four samples share the same story:

1. **users** — `INSERT` / `UPDATE` / batched `INSERT`.
2. **products** — `ALTER TABLE ADD / RENAME / DROP COLUMN`.
3. **orders → orders_archive** — `ALTER TABLE RENAME TO`.

Each step prints a `[LOCAL ...]` banner. After `awaitSync` / `await_sync`, Java / Python / Rust reconnect to Postgres and print `[POSTGRES ...]` lines that show the same data and the same schema on the destination. The C++ sample prints copy-paste `psql` queries for the same verification (avoids linking `libpq`).

Every sample is **safe to rerun on the same device** — each table is `DROP TABLE IF EXISTS`'d before being recreated.

## Device families

These runtime samples all use a **SQL device** — a full, SQLite-syntax-compliant embedded SQL database where you run arbitrary `CREATE` / `ALTER` / `SELECT` / `INSERT` / `UPDATE` / `DELETE` and have every change replicated to the destination. It's the right starting point when your app needs real SQL, JOINs, multi-statement transactions, or ad-hoc DDL.

SyncLite also ships two other device families on the same runtime:

- **Store devices** — the same SQL-shaped API tuned for bulk write-through; the runtime emits pre-formed row events that the Consolidator applies directly to the destination, giving the highest end-to-end consolidation throughput and the simplest starting point for a new app.
- **Streaming devices** — append-only ingestion for high-throughput event capture; accept `INSERT` + DDL and reject `UPDATE` / `DELETE` by design.

All three produce the same change log and flow through the same shipper + consolidator, so you can mix device families inside one application. See [../README.md § SyncLite Devices](../README.md#synclite-devices--three-apis-over-one-runtime) for the full device-family reference and [../DOCUMENTATION.md](../DOCUMENTATION.md) for per-device API details.

## Sync modes: `REPLICATION` vs `CONSOLIDATION`

Each sample picks one of two destination sync modes — set on the device at `initialize(...)` (or in `synclite.conf` as `dst-sync-mode=...`):

- **`REPLICATION`** (the default in these samples) — **one device → one destination, mirrored 1:1.** The destination table is owned by this device; `INSERT` / `UPDATE` / `DELETE` / `DROP TABLE` / `DROP COLUMN` / `RENAME` / `TRUNCATE` all apply faithfully on the destination. Use this when each app instance has its own database and you want the destination to look identical to the source.

- **`CONSOLIDATION`** (the advanced mode) — **many devices → one shared destination table.** Lets you fan in writes from thousands of edge devices into a single warehouse table. The consolidator is conservative on shared state: it ignores `DROP TABLE` / `DROP COLUMN`, rewrites `RENAME COLUMN` as `ADD COLUMN` and `RENAME TABLE` as `CREATE TABLE`, and skips bulk `DELETE WHERE` / `UPDATE WHERE` (only PK-targeted row ops are applied). This protects the table from a single misbehaving device.

For the full per-operation truth table see [DOCUMENTATION.md §9.5](../DOCUMENTATION.md#95-sync-modes-replication-vs-consolidation). The Java and Rust / Python / C++ runtimes apply identical semantics in both modes.

To flip a sample to `CONSOLIDATION`, change the literal in the `DestinationOptions` block at the top of the sample:

| Language | Field | Replication | Consolidation |
|---|---|---|---|
| Java   | `.syncMode(...)`   | `DstSyncMode.REPLICATION`   | `DstSyncMode.CONSOLIDATION` |
| Rust   | `dst_sync_mode:`   | `DstSyncMode::Replication`  | `DstSyncMode::Consolidation` |
| Python | `dst_sync_mode=`   | `"REPLICATION"`             | `"CONSOLIDATION"` |
| C++    | `dst_sync_mode =`  | `"REPLICATION"`             | `"CONSOLIDATION"` |
| Conf   | `dst-sync-mode=`   | `REPLICATION`               | `CONSOLIDATION` |

## Postgres prereq (all four samples)

One-time, on the Postgres server:

```sql
CREATE DATABASE syncdb;
\c syncdb
CREATE SCHEMA syncschema;
```

All four samples default to `postgresql://postgres:postgres@localhost:5432/syncdb` and schema `syncschema`. Edit the constants at the top of the sample to match your environment.

> **Rust, Python, and C++ samples** drive the Rust runtime, which auto-creates the destination schema on first run (`CREATE SCHEMA IF NOT EXISTS`). For those three the `CREATE SCHEMA` line above is optional. The Java sample still expects the schema to exist.

## Where do the samples write files?

When a sample runs (e.g. `SyncliteSqlitePostgresApp` with `dbPath = sample.db` and `deviceName = sampledevice`), SyncLite writes to three roots:

| What | Path |
|---|---|
| Your local DB file | `<cwd>/sample.db` (whatever you pass to `initialize(dbPath, ...)`) |
| Logger trace + trigger files | `<cwd>/sample.db.synclite/sample.db.trace` |
| Outbound `.sqllog` segments | `<userHome>/synclite/job1/stageDir/synclite_sampledevice_<uuid>/` |
| In-process consolidator state + `synclite_device.trace` | `<userHome>/synclite/job1/workDir/synclite_sampledevice_<uuid>/` |

> **Sample failing?** Check both trace files — `<dbPath>.synclite/<dbName>.trace` (logger-side: config / log-write / schema-evolution errors on the local DB) and `<userHome>/synclite/job1/workDir/synclite_<deviceName>_<uuid>/synclite_device.trace` (destination-side: Postgres auth failures, missing schema, DDL conflicts).

Full reference: [GETTING_STARTED.md § Where does SyncLite put its files?](../GETTING_STARTED.md#where-does-synclite-put-its-files).
