# SyncLite Logger — Rust Samples

Pure-Rust samples that turn a local SQLite or DuckDB database into an
**offline-first edge app that automatically syncs every change to a remote
destination** — PostgreSQL is the marquee example below.

There is no JVM, no JAR, no separate consolidator process: everything
(logger + segment shipper + embedded consolidator) runs in your binary.

## Two ways to consume the `synclite` crate

### Option A — path dependency on the in-tree workspace

The default in [`Cargo.toml`](Cargo.toml). Useful when you have the
platform repo checked out (recommended for contributors and pre-release
tracking):

```toml
[dependencies]
synclite          = { path = "../../../synclite-logger-rust/crates/synclite" }
logger-core       = { path = "../../../synclite-logger-rust/crates/logger/core" }
logger-db-traits  = { path = "../../../synclite-logger-rust/crates/logger/db-traits" }
```

`cargo run --example <name>` rebuilds against the freshest in-tree code.

### Option B — published crates.io release

Useful when you just want to embed SyncLite in a Rust project without
the platform repo. Replace the path dependencies above with:

```toml
[dependencies]
synclite          = "0.1"
logger-core       = "0.1"
logger-db-traits  = "0.1"
```

Both options expose the exact same `synclite::` API — the sample
sources compile against either.

## Marquee sample — local SQLite syncing to remote PostgreSQL

[synclite_rusqlite_postgres.rs](synclite_rusqlite_postgres.rs) is the canonical
end-to-end demo: a SQLite-backed app that ships every committed change to a
PostgreSQL database, with a deterministic `await_sync` checkpoint so a
short-lived program can guarantee the data has landed before it exits.

### Prereqs

A reachable PostgreSQL instance with a database and schema for the demo:

```sql
CREATE DATABASE syncdb;
\c syncdb
CREATE SCHEMA syncschema;
```

The sample uses `postgresql://postgres:postgres@localhost:5432/syncdb` and
schema `syncschema`. Edit `synclite_rusqlite_postgres.rs` to match your
credentials.

### Run

```powershell
cargo run --example synclite_rusqlite_postgres
```

Four rows are printed locally and replicated to PostgreSQL:

```sql
SELECT * FROM syncschema.users ORDER BY id;
```

### What the code does

```rust
synclite::initialize(
    DeviceType::Sqlite,
    DEVICE_NAME,
    DB_PATH,
    Some(DestinationOptions {
        dst_type: DstType::Postgres,
        dst_connection_string:
            "postgresql://postgres:postgres@localhost:5432/syncdb".into(),
        dst_database: Some("syncdb".into()),
        dst_schema: Some("syncschema".into()),
        dst_sync_mode: DstSyncMode::Consolidation,
    }),
    SyncLiteOptions::default(),
)?;

let mut conn = Connection::open(DB_PATH)?;
// ... CREATE / INSERT / UPDATE through rusqlite-style API ...
let local_rows = conn.query("SELECT id, name FROM users WHERE id = 1", &[])?;
println!("[READ FROM LOCAL DB] {:?}", local_rows.first());
conn.flush()?;                                            // roll the active log segment
match synclite::await_sync(DB_PATH, Duration::from_secs(30)) {
    Ok(()) => {
        println!("[SYNC] await_sync succeeded");
        let mut pg = postgres::Client::connect(
            "postgresql://postgres:postgres@localhost:5432/syncdb",
            postgres::NoTls,
        )?;
        let pg_row = pg.query_opt(
            "SELECT row_to_json(t)::text FROM (SELECT * FROM syncschema.users WHERE id = $1) t",
            &[&1_i64],
        )?;
        println!("[READ FROM POSTGRESQL POST SYNC] {:?}", pg_row);
    }
    Err(e) => println!("[SYNC] await_sync failed: {e}"),
}
conn.close()?;
```

`synclite::initialize` wires up the local logger, the segment shipper, and
the in-process consolidator that drains into PostgreSQL. From there the
app uses a normal rusqlite-style `Connection` — there are no network calls
in the hot write path; sync happens asynchronously in the background.

## Sibling samples

Every sample below uses the same canonical shape as the marquee sample
(initialize → connection ops → `flush` → `await_sync`). They default to
**local-only** so they run without any remote dependency; flip on the
PostgreSQL destination by replacing the `None` with a `Some(DestinationOptions { … })`
block — see the commented snippet in [`synclite_rusqlite.rs`](synclite_rusqlite.rs).

| File | Device type | Highlights |
|------|------------|------------|
| [synclite_rusqlite_postgres.rs](synclite_rusqlite_postgres.rs) | `Sqlite` | **Marquee** — local SQLite syncing to PostgreSQL |
| [synclite_rusqlite.rs](synclite_rusqlite.rs) | `Sqlite` | Local-only SQLite device, no destination |
| [synclite_rusqlite_store.rs](synclite_rusqlite_store.rs) | `SqliteStore` | Bulk-friendly SQLite STORE device |
| [synclite_duckdb.rs](synclite_duckdb.rs) | `DuckDb` | Local-only DuckDB device |
| [synclite_duckdb_store.rs](synclite_duckdb_store.rs) | `DuckDbStore` | Bulk-friendly DuckDB STORE device |
| [synclite_streaming.rs](synclite_streaming.rs) | `Streaming` | Append-only events (UPDATE/DELETE rejected by design) |
| [synclite_device_artifacts_demo.rs](synclite_device_artifacts_demo.rs) | mixed | Walkthrough of the on-disk artifacts |
| [synclite_reinitialize.rs](synclite_reinitialize.rs) | `Sqlite` | Reset a device with `synclite::reinitialize` (clean-destination + re-seed) |

Run any of them with:

```powershell
cargo run --example <name>
```

## Defaults

With no config file, SyncLite uses:

- Local stage directory: `<user-home>/synclite/job1/stageDir`
- Consolidator work directory: `<user-home>/synclite/job1/workDir`

Each device gets its own subdirectory under `workDir` named
`synclite-<device-name>-<uuid>/`. For richer setups (multiple destinations,
mappers, Prometheus, alternate stage transports) pass a `synclite.conf` via
`SyncLiteOptions::config_path` — see the platform README at
[../../../synclite-logger-rust/README.md](../../../synclite-logger-rust/README.md)
for the full configuration reference.

## Resetting a device

`synclite::reinitialize(db_path, clean_destination)` wipes per-device local
state and the device's destination metadata so the next
`synclite::initialize` re-seeds from scratch under the same UUID and device
name. In `REPLICATION` mode `clean_destination=true` also drops the user
tables owned by this device on the destination; in `CONSOLIDATION` mode
dropping is a safe no-op (the destination is shared across many devices).

For out-of-process tooling, drop one of these files alongside the database
and the next `synclite::initialize` will run the reinit and remove the
trigger:

```text
reinitialize.<device-name>                          # preserve destination
reinitialize_with_clean_destination.<device-name>   # clean destination
```

## Pause / resume sync

`synclite::pause_sync(db_path)` halts only the consolidator's apply step —
the in-process logger keeps appending segments locally and the shipper keeps
publishing them to the upload root. `synclite::resume_sync(db_path)` drains
the queue in order. State is persisted in a sentinel file under the device
home so it survives process restarts. Both calls are idempotent;
`synclite::is_sync_paused(db_path)` returns the current bit.

Trigger-file protocol (consumed at the top of `synclite::initialize`):

```text
pause_sync.<device-name>     # pauses on next bring-up
resume_sync.<device-name>    # resumes on next bring-up
```

## Inspecting sync state

Three read-only helpers report what the consolidator is doing for a device.
No workers are started and no destination round-trips are made.

```rust
let st = synclite::sync_status(db_path)?;
// st.state is SyncState::NotInitialized | Paused | Running

let s = synclite::sync_statistics(db_path)?;
// segments-applied, ops, txns, bytes, last consolidated commit id,
// last heartbeat time.

let l = synclite::sync_latency(db_path)?;
// l.latency_ms = source - applied (wall-clock ms); -1 when unknown.
```

`latency_ms` is a true wall-clock figure because every `commit_id` is a
`System.currentTimeMillis()` value emitted by the logger.

## Standalone build

If you copy this folder outside the platform repo, swap the path
dependencies in [`Cargo.toml`](Cargo.toml) for the published versions:

```toml
synclite = "0.1"
logger-core = "0.1"
logger-db-traits = "0.1"
```
