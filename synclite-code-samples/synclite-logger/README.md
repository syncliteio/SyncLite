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

Python samples drive the Rust runtime through the `synclite` PyO3
bindings — no JVM, no JAR. See `python/README.md` for build / install
instructions.

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
