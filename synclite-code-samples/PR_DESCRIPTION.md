# PR Description -- synclite-code-samples

## Scope
The cross-language samples tree is rewritten from the previous two-level layout (`synclite-runtime/` + `synclite-db/` with one sample per binding / mode, and a large amount of leftover build / database artifacts checked in) to a flat per-language layout with **one canonical sample per language** (SQLite source -> Postgres destination, single device, `REPLICATION` mode) and a clear "run from the release zip" path.

## Files Changed

### Deleted
The entire `synclite-runtime/` and `synclite-db/` subtrees, including all of the following classes of files:
- One sample per binding per language: `synclite_rusqlite.{cpp,py,rs}`, `synclite_rusqlite_store.{cpp,py}`, `synclite_duckdb.{cpp,py,rs}`, `synclite_duckdb_store.{cpp,py,rs}`, `synclite_streaming.{cpp,py}`, plus 10 Java samples (`SyncLiteJedisAPIApp`, `SyncLiteKafkaProduceApp`, `SyncLiteStoreAPIApp`, `SyncLiteStoreDeviceApp`, `SyncLiteStreamAPIApp`, `SyncLiteStreamingApp`, `SyncliteDeviceApp`, `SyncliteSqlitePostgresApp`, `SyncLiteBulkTxnParityApp`, and the misplaced `SyncLiteBulkTxnParityApp.class`) and one Rust experiment crate.
- `synclite-db/` REST-client samples in seven languages (`c#`, `cpp`, `go`, `java`, `node.js`, `python`, `ruby`, `rust`) -- these were thin HTTP wrappers around the `synclite-db` server endpoints and duplicated information already in `synclite-db/README.md`.
- All per-language `README.md` files inside the deleted subtrees.
- Per-language config files (`synclite.conf`, `synclite_logger.conf`).
- Accidental build / runtime artifacts that were checked in over time: `derby.log`, `_out.txt`, `build2.log`, `build_check.log`, `build_reinit.log`, `run.log`, `run_out.txt`, `samples_build.log`, the entire `sample_rusqlite_sqlite.db.synclite/` device folder (containing `*.lock`, `*.backup`, `*.metadata`, `*.trace`, `synclite_device_metadata.db`), `Cargo.lock` of the experiment crate, and `SyncLiteBulkTxnParityApp.class`. These were polluting `git status` on every sample run and inflating the repo / release-zip size.

### Added
Flat per-language layout under `synclite-code-samples/`:

- **`README.md`** -- single overview that:
  - Names the canonical sample (`synclite_rusqlite_postgres` -- SQLite source via `rusqlite` / JDBC / `sqlite3` / `<sqlite3.h>` -> Postgres destination via the in-process consolidator).
  - States the sync-mode default (`REPLICATION`) and cross-links `DOCUMENTATION.md` section 9.5 for the consolidation-vs-replication trade-off.
  - Lists the Postgres prereq (`bin/dst/postgresql/docker-compose.yml` brings up `postgres:16-alpine` with user/pass `postgres/postgres`, db `syncdb`, schema `syncschema` -- matches what the four samples connect to).
  - Per-language jump-off table -> `cpp/README.md`, `java/README.md`, `python/README.md`, `rust/README.md`.

- **`cpp/`**
  - `synclite_rusqlite_postgres.cpp` -- canonical sample: opens local SQLite, inserts a few rows, configures Postgres destination with `dst_sync_mode = "REPLICATION"`, calls `synclite_await_sync` with a 30 s timeout.
  - `CMakeLists.txt` -- auto-detects the release-shipped headers (`lib/native/include/synclite.{h,hpp}`) and native library (`lib/native/libsynclite_*` with broadened glob to match per-platform names: `libsynclite_clib.{so,dylib,dll}`, `libsynclite_logger.*`, etc.).
  - `README.md` -- "Run from the release zip" + the optional source-build path.

- **`java/`**
  - `SyncliteSqlitePostgresApp.java` -- canonical sample (SQLite -> Postgres, in-process consolidator, `DstSyncMode.REPLICATION`, `awaitSync` 30 s). Embeds Postgres creds in the JDBC URL so it is copy-paste runnable.
  - `README.md` -- compile + run via `java -cp ../../lib/java/synclite-1.0.0.jar:. SyncliteSqlitePostgresApp` (release zip) or `../../synclite-logger-java/logger/target/synclite-1.0.0.jar` (source-build).

- **`python/`**
  - `synclite_rusqlite_postgres.py` -- canonical sample using the PyO3 `synclite` package (the wheel shipped by `lib/python/synclite-*.whl`).
  - `README.md` -- "Run from the release zip" via `pip install ../../lib/python/synclite-*.whl` first; optional source-build path via `cd synclite-logger-rust/python && maturin develop --release`.

- **`rust/`**
  - `synclite_rusqlite_postgres.rs` -- canonical sample using the `synclite` facade crate.
  - `Cargo.toml` -- path-deps into `lib/rust/synclite-source/` (the Cargo workspace staged by the parent pom's `stage-rust-source-tree` antrun execution). `cargo run` works offline from the release tree -- no crates.io / no GitHub access required.
  - `synclite.conf` -- matching consolidator config (Postgres destination, `dst-sync-mode=REPLICATION`).
  - `README.md` -- "Run from the release zip" using `cargo run --release` against the staged workspace.

## Rationale
- Previous tree had ~30 samples spanning every binding x device-type x destination-type combination plus several Kafka / Redis / Streaming variants. Onboarding feedback was that the matrix was overwhelming and the "first thing to run" was unclear. Single canonical sample per language tells a clear single story (SQLite source -> Postgres destination, `REPLICATION` default).
- Every per-language sample now runs the **same workload** so users can move horizontally across languages and recognize the API shape.
- "Run from the release zip" path is documented first in every per-language README -- a user who downloaded `synclite-platform-1.0.0.zip`, expanded it, and started Postgres can be running their first sample in three commands. Source-build path is documented second.
- Native sample `CMakeLists.txt` glob broadened from the previous hard-coded `libsynclite_clib.*` to `libsynclite_*` so the same `cmake` invocation finds the right artifact on Windows / Linux / macOS.

## Validation
- `cmake -S synclite-code-samples/cpp -B build/cpp -DSYNCLITE_RELEASE_DIR=target/synclite-platform-1.0.0 && cmake --build build/cpp` -> builds `synclite_rusqlite_postgres` against the release-shipped headers + lib on Windows / Linux / macOS.
- `cd synclite-code-samples/java && javac -cp ../../target/synclite-platform-1.0.0/lib/java/synclite-1.0.0.jar SyncliteSqlitePostgresApp.java && java ...` -> compiles + runs end-to-end against local Postgres, `awaitSync` returns within 30 s.
- `cd synclite-code-samples/python && pip install ../../target/synclite-platform-1.0.0/lib/python/synclite-*.whl && python synclite_rusqlite_postgres.py` -> same.
- `cd synclite-code-samples/rust && cargo run --release --offline` -> picks up path-deps into `lib/rust/synclite-source/`, builds clean, runs end-to-end.
- `git status` in the samples tree after running each sample is clean -- no `*.log`, no `*.db`, no `*.class` reappears in the tracked set (they all sit inside the gitignored device-folder or `target/` outputs).

## Related
- Top-level [`PR_DESCRIPTION_MAIN.md`](../PR_DESCRIPTION_MAIN.md) -- documents the matching `assembly/*.xml` fileSet additions (`lib/python/*.whl`, `lib/rust/synclite-source/`, `lib/native/include/synclite.{h,hpp}`) that make the "Run from the release zip" path work.
- Java sample defaults: [`synclite-logger-java/PR_DESCRIPTION.md`](../synclite-logger-java/PR_DESCRIPTION.md) -- the `samples/` folder in that module was flipped to the same `REPLICATION` default in the same release.
- Mode semantics: `DOCUMENTATION.md` section 9.5 `Sync Modes: Replication vs Consolidation`.
