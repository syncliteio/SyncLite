# SyncLite Runtime Samples

One end-to-end sample per language, each demonstrating the same story: a local SQLite database whose every change — DML **and** schema evolution — is replicated to PostgreSQL by the in-process consolidator.

| Language | Sample | Folder README |
|---|---|---|
| Java   | [`SyncliteSqlitePostgresApp.java`](java/SyncliteSqlitePostgresApp.java)            | [java/README.md](java/README.md) |
| Python | [`synclite_rusqlite_postgres.py`](python/synclite_rusqlite_postgres.py)            | [python/README.md](python/README.md) |
| Rust   | [`synclite_rusqlite_postgres.rs`](rust/synclite_rusqlite_postgres.rs)              | [rust/README.md](rust/README.md) |
| C++    | [`synclite_rusqlite_postgres.cpp`](cpp/synclite_rusqlite_postgres.cpp)             | [cpp/README.md](cpp/README.md) |

All four samples share the same story:

1. **users** — `INSERT` / `UPDATE` / batched `INSERT`.
2. **products** — `ALTER TABLE ADD / RENAME / DROP COLUMN`.
3. **orders → orders_archive** — `ALTER TABLE RENAME TO`.

Each step prints a `[LOCAL ...]` banner. After `awaitSync` / `await_sync`, Java / Python / Rust reconnect to Postgres and print `[POSTGRES ...]` lines that show the same data and the same schema on the destination. The C++ sample prints copy-paste `psql` queries for the same verification (avoids linking `libpq`).

Every sample is **safe to rerun on the same device** — each table is `DROP TABLE IF EXISTS`'d before being recreated.

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
