# SyncLite Logger Samples

This folder contains the canonical sample set requested for this repository.

## Java

- SyncliteDeviceApp.java
- SyncLiteStoreDeviceApp.java (replaces previous Appender sample)
- SyncLiteStreamingApp.java
- SyncLiteStoreAPIApp.java
- SyncLiteStreamAPIApp.java
- SyncLiteKafkaProduceApp.java
- SyncLiteJedisAPIApp.java

## Python

Five Python samples drive the SyncLite Rust runtime via the
[`synclite`](../../synclite-logger-rust/python/) PyO3 wheel —
mirroring the Rust API 1:1 (`Connection`, `Statement`,
`DuckDBConnection`, `DuckDBStatement`, plus module-level `initialize`
and `await_sync`). No JVM, no JAR — install the wheel with
`maturin develop --release` from `synclite-logger-rust/python/`.

See `python/README.md` for full install + run instructions.

- `synclite_rusqlite.py` (SQLITE)
- `synclite_rusqlite_store.py` (SQLITE_STORE)
- `synclite_streaming.py` (STREAMING)
- `synclite_duckdb.py` (DUCKDB)
- `synclite_duckdb_store.py` (DUCKDB_STORE)

## Rust

Rust samples in `rust/` use the `synclite` wrapper crate directly. See
`rust/README.md`.

- `synclite_rusqlite.rs` (SQLITE)
- `synclite_rusqlite_store.rs` (SQLITE_STORE)
- `synclite_streaming.rs` (STREAMING)
- `synclite_duckdb.rs` (DUCKDB)

## C++

C++ samples in `cpp/` drive the Rust runtime through the C ABI
(`synclite.h`) wrapped in a header-only C++17 RAII layer
(`synclite.hpp`). See `cpp/README.md` for build instructions.

- `synclite_rusqlite.cpp` (SQLITE)
- `synclite_rusqlite_store.cpp` (SQLITE_STORE)
- `synclite_streaming.cpp` (STREAMING)
- `synclite_duckdb.cpp` (DUCKDB)
- `synclite_duckdb_store.cpp` (DUCKDB_STORE)

See language-specific README files for quick run instructions.
