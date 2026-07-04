# SyncLite C++ Sample (SQLite -> PostgreSQL)

This folder contains one end-to-end sample:

- [synclite_rusqlite_postgres.cpp](synclite_rusqlite_postgres.cpp)

The program writes to a local SQLite database and uses SyncLite's embedded pipeline to replicate data and schema changes to PostgreSQL.

The sample demonstrates:

1. DML replication: INSERT / UPDATE / batch INSERT
2. Schema evolution replication: ADD / RENAME / DROP COLUMN
3. Table rename replication: RENAME TO
4. Flush + await_sync for deterministic completion

## Prerequisites

1. PostgreSQL reachable from this machine
2. Database and schema created
3. C++ toolchain + CMake

Create DB + schema once:

```sql
CREATE DATABASE syncdb;
\c syncdb
CREATE SCHEMA syncschema;
```

Default connection used by the sample:

- host: `localhost`
- port: `5432`
- user/password: `postgres/postgres`
- db: `syncdb`
- schema: `syncschema`

If needed, edit constants in [synclite_rusqlite_postgres.cpp](synclite_rusqlite_postgres.cpp).

## Run From Packaged Platform (Recommended)

From an extracted platform folder, open terminal in:

- `sample-apps/cpp`

Expected layout relative to this folder:

```text
../../lib/native/include/synclite.h
../../lib/native/include/synclite.hpp
../../lib/native/libsynclite_<version>.dll   (Windows)
../../lib/native/libsynclite_<version>.lib   (Windows)
```

### Windows (PowerShell)

If `cmake` is on PATH:

```pwsh
cmake -S . -B build
cmake --build build --config Release
.\build\Release\synclite_rusqlite_postgres.exe
```

If `cmake` is not on PATH (Visual Studio bundled CMake):

```pwsh
$cmake = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
& $cmake -S . -B build
& $cmake --build build --config Release
.\build\Release\synclite_rusqlite_postgres.exe
```

### Linux / macOS

```bash
cmake -S . -B build
cmake --build build
./build/synclite_rusqlite_postgres
```

If loader cannot find SyncLite runtime libs, set:

- Linux: `LD_LIBRARY_PATH=../../lib/native`
- macOS: `DYLD_LIBRARY_PATH=../../lib/native`

## Run From Source Checkout

If you are in this repository (not extracted package), build Rust runtime first:

```pwsh
cd ..\..\synclite-logger-rust
cargo build -p synclite-c --release
cd ..\synclite-code-samples\cpp
cmake -S . -B build -DSYNCLITE_RUST_ROOT=..\..\synclite-logger-rust -DSYNCLITE_PROFILE=release
cmake --build build --config Release
.\build\Release\synclite_rusqlite_postgres.exe
```

## Device Types (C++ / Rust Runtime)

To switch device type, edit the initialize call in [synclite_rusqlite_postgres.cpp](synclite_rusqlite_postgres.cpp):

```cpp
sl::initialize("SQLITE", DEVICE_NAME, DB_PATH, dst);
```

Valid values for the first argument are:

1. `SQLITE`: full SQL device on SQLite
2. `SQLITE_STORE`: store-oriented SQL device on SQLite
3. `DUCKDB`: full SQL device on DuckDB
4. `DUCKDB_STORE`: store-oriented SQL device on DuckDB
5. `STREAMING`: append-only streaming device

Quick examples:

```cpp
sl::initialize("SQLITE_STORE", DEVICE_NAME, DB_PATH, dst);
sl::initialize("DUCKDB", DEVICE_NAME, DB_PATH, dst);
sl::initialize("DUCKDB_STORE", DEVICE_NAME, DB_PATH, dst);
sl::initialize("STREAMING", DEVICE_NAME, DB_PATH, dst);
```

Behavior notes:

1. `STREAMING` is append-oriented and does not support general `UPDATE`/`DELETE` workflows like full SQL devices.
2. `DUCKDB` and `DUCKDB_STORE` may require `duckdb.dll` on Windows next to the executable depending on packaging.
3. The sample flow itself is written for SQL semantics; if you switch to `STREAMING`, adapt statements accordingly.

## What Success Looks Like

Program output includes these banners:

1. `TABLE users`
2. `TABLE products`
3. `TABLE orders -> orders_archive`
4. `SYNC: flush + await_sync`

Then it prints SQL snippets under `VERIFY on PostgreSQL` so you can validate destination state manually.

## Troubleshooting

### Configure fails: cannot find synclite library

Symptom:

- `Could not find a synclite_c / libsynclite_<revision> library ...`

Checks:

1. Confirm `../../lib/native` exists from this folder
2. Confirm it contains `.lib/.dll` (Windows) or `.so/.dylib` (Linux/macOS)
3. If sample moved outside package layout, pass `-DSYNCLITE_SDK_DIR=<sdk-root>`

### Windows run fails with `0xC0000135`

This is a missing DLL.

Common fixes:

1. Ensure the SyncLite runtime DLL is next to the built `.exe`
2. Ensure `duckdb.dll` is next to the `.exe` when required by your runtime build

If your package only has the versioned runtime DLL, keep it next to the exe as-is (for example `libsynclite_1.0.0.dll`).

### No rows appear in PostgreSQL

1. Verify connection string in sample code
2. Confirm DB/schema exists
3. Wait for `await_sync` success
4. Run printed verification SQL

## Notes

1. Re-running is safe; tables are dropped/recreated in sample flow
2. C++ sample intentionally avoids `libpq` dependency and prints SQL verification steps instead
