# SyncLite Rust sample

[`synclite_rusqlite_postgres.rs`](synclite_rusqlite_postgres.rs) — local SQLite app whose every change is replicated to PostgreSQL by the in-process consolidator. Pure Rust — no JVM, no jar, no separate consolidator process.

Top-of-file comments show where to flip **sync mode** (`REPLICATION` ↔ `CONSOLIDATION` — see [../README.md § Sync modes](../README.md#sync-modes-replication-vs-consolidation)) and swap connection settings.

## Run from the release zip

You are already in `sample-apps/rust/` of an extracted release. The release ships the SyncLite Rust SDK source under [`../../lib/rust/synclite-source/`](../../lib/rust/synclite-source/) — a self-contained Cargo workspace with the `synclite` facade + logger + consolidator + observability crates. The sample's [`Cargo.toml`](Cargo.toml) already points into that tree via path dependencies, so it builds **offline against the bundled crates** with no extra setup.

### 1. Pre-create the Postgres database (one-time)

```sql
CREATE DATABASE syncdb;
```

Defaults: `postgresql://postgres:postgres@localhost:5432/syncdb`, schema `syncschema` (auto-created on first run). Edit the constants at the top of the `.rs` to override.

### 2. Run

```pwsh
cargo run --example synclite_rusqlite_postgres
```

First run downloads third-party crates (`rusqlite`, `postgres`, `tokio`, …) to `~/.cargo`; no SyncLite crate ever leaves the release zip. Safe to rerun — each table is `DROP TABLE IF EXISTS`'d before being recreated.

## What you'll see

Three flows executed locally on SQLite, each step printing a `[LOCAL ...]` banner:

1. **users** — `INSERT` / `UPDATE` / batched `INSERT`.
2. **products** — `ALTER TABLE ADD / RENAME / DROP COLUMN`.
3. **orders → orders_archive** — `ALTER TABLE RENAME TO`.

Then `synclite::await_sync` blocks until the in-process shipper + consolidator have drained to Postgres, and a `[POSTGRES …]` block reconnects with the `postgres` crate and prints the same rows + same schema from the destination.

## Defaults

With no config file, SyncLite uses:

- Local stage directory: `<user-home>/synclite/job1/stageDir`
- Consolidator work directory: `<user-home>/synclite/job1/workDir`

Each device gets its own subdirectory under `workDir` named `synclite-<device-name>-<uuid>/`. For richer setups (multiple destinations, mappers, Prometheus, alternate stage transports) pass a `synclite.conf` via `SyncLiteOptions::config_path`.

## Troubleshooting

- **`error: linker 'link.exe' not found`** on Windows — install Visual Studio Build Tools with the "Desktop development with C++" workload.
- **`connection refused` to Postgres** — confirm Postgres is listening on `localhost:5432` and the credentials in the sample match.
- **Nothing landed on Postgres** — check the trace files documented in [../README.md § Where do the samples write files?](../README.md#where-do-the-samples-write-files).

---

## Developing against the repo

If you're iterating on the `synclite` crate from a repo checkout *without* running `mvn package` first, use the alternate sample at [`../../synclite-logger-rust/samples/rust/`](../../synclite-logger-rust/samples/rust/) — its `Cargo.toml` points directly at the in-tree workspace crates under `synclite-logger-rust/crates/` and picks up local edits without a Maven rebuild. Both samples expose the exact same `synclite::` API.
