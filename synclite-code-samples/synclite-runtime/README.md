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

Python samples drive the SyncLite Rust runtime two ways:

- `synclite_quickstart.py` runs **today** against the C ABI via the
  thin [`synclite`](../../synclite-logger-rust/python/synclite.py) ctypes
  wrapper. No `pip install`, no JVM, no JAR — just the cdylib already in
  `lib/native/` and one Python file in `lib/python/`.
- The other five samples (`synclite_rusqlite*.py`, `synclite_streaming.py`,
  `synclite_duckdb*.py`) preview the future
  [`synclite-logger-python`](https://github.com/synclite) PyO3 wheel
  (richer `Connection` / `Statement` / `await_sync` API, DB-API 2.0,
  SyncLiteStore, SyncLiteStream, Redis / Kafka compatibility).

See `python/README.md` for run instructions.

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
