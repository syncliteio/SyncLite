# SyncLite C++ sample

[`synclite_rusqlite_postgres.cpp`](synclite_rusqlite_postgres.cpp) — local SQLite app whose every change is replicated to PostgreSQL by the in-process consolidator. Built on the SyncLite C ABI (`synclite.h`) wrapped in a header-only C++17 RAII layer (`synclite.hpp`).

Top-of-file comments show where to flip **sync mode** (`REPLICATION` ↔ `CONSOLIDATION` — see [../README.md § Sync modes](../README.md#sync-modes-replication-vs-consolidation)) and adjust connection settings.

> **Postgres verification.** Unlike Java / Python / Rust, the C++ sample does *not* link `libpq` (avoids a non-trivial build dependency). After `await_sync` it prints copy-paste `psql` queries you can run from a separate shell to confirm the same rows + same schema landed.

## Run from the release zip

You are already in `sample-apps/cpp/` of an extracted release. The release ships the C/C++ SDK under [`../../lib/native/`](../../lib/native/):

```
../../lib/native/
    include/synclite.h        # C ABI
    include/synclite.hpp      # C++17 RAII wrapper (header-only)
    libsynclite_1.0.0.dll              # Windows runtime
    libsynclite_1.0.0.lib              # Windows import library
    libsynclite_1.0.0_linux_x86_64.so  # Linux x86_64
    libsynclite_1.0.0_linux_aarch64.so # Linux arm64
```

[`CMakeLists.txt`](CMakeLists.txt) auto-detects this layout — no flags needed.

### 1. Pre-create the Postgres database + schema (one-time)

```sql
CREATE DATABASE syncdb;
\c syncdb
CREATE SCHEMA syncschema;
```

Defaults: schema `syncschema`. Edit the constants at the top of the `.cpp` to override.

### 2. Build + run

```pwsh
cmake -S . -B build
cmake --build build --config Release
```

Then:

**Windows:**

```pwsh
.\build\Release\synclite_rusqlite_postgres.exe
```

**Linux / macOS:**

```bash
./build/synclite_rusqlite_postgres
```

CMake copies the SyncLite cdylib next to the executable on Windows. On Linux set `LD_LIBRARY_PATH=../../lib/native` (or `DYLD_LIBRARY_PATH` on macOS) before running if the loader can't find it.

Safe to rerun — each table is `DROP TABLE IF EXISTS`'d before being recreated.

## What you'll see

Three flows executed locally on SQLite, each step printing a `[LOCAL ...]` banner:

1. **users** — `INSERT` / `UPDATE` / batched `INSERT`.
2. **products** — `ALTER TABLE ADD / RENAME / DROP COLUMN`.
3. **orders → orders_archive** — `ALTER TABLE RENAME TO`.

Then `synclite::await_sync` blocks until the in-process shipper + consolidator have drained to Postgres. A final `[POSTGRES VERIFY]` block prints the `psql` queries you can run to confirm the same rows + same schema landed.

## Troubleshooting

- **`Could not find synclite_c / synclite_1.0.0`** at CMake configure — verify `../../lib/native/` exists relative to this folder. If you moved the sample out of the release tree, pass `-DSYNCLITE_SDK_DIR=<path-to-lib/native-or-equivalent>`.
- **`synclite_*.dll not found`** at run time on Windows — the CMake post-build step copies the dll next to the `.exe`; if you moved the exe, copy the dll alongside it.
- **Nothing landed on Postgres** — check the trace files documented in [../README.md § Where do the samples write files?](../README.md#where-do-the-samples-write-files).

---

## Developing against the repo

If you're working from a `synclite` repo checkout instead of an extracted release, build the cdylib from source first:

```pwsh
cd ..\..\synclite-logger-rust
cargo build -p synclite-c --release
cd ..\synclite-code-samples\cpp
cmake -S . -B build -DSYNCLITE_RUST_ROOT=..\..\synclite-logger-rust -DSYNCLITE_PROFILE=release
cmake --build build --config Release
```

CMake then picks up `synclite-logger-rust/target/release/synclite_c.{dll,lib,so}` automatically.
