# SyncLite Logger — Python Samples

There are **two** Python entry points to the SyncLite Rust runtime, at
two different maturity levels — pick the one that matches what you
need today.

## 1. `synclite_quickstart.py` — ships today, works today

A small, dependency-free sample driven by the
[`synclite`](../../../synclite-logger-rust/python/synclite.py) ctypes
wrapper. It uses the seven-function C ABI exposed by
`synclite-bindings-c` (the same cdylib that backs the C / C++ / Java
JNI / FFI bindings) and the platform-native binary already shipped in
every release zip under `lib/native/`.

```pwsh
# from inside an unpacked release zip (no install step at all)
cd sample-apps\python
python synclite_quickstart.py
```

No `pip install`, no Rust toolchain, no maturin — the `synclite` Python
module is the single file at `lib/python/synclite.py` and the quickstart
imports it automatically by walking up to find the sibling `lib/python/`
folder.

The C ABI surface today is intentionally small: `Runtime.open_config`,
`log_sql`, `commit`, `flush_log`, `rollback`, `close`. Parameter binding
is not yet plumbed through, so SQL values are inlined in the quickstart.

### Override the native library location

The wrapper finds `libsynclite_oss.{dll,so,dylib}` automatically when run
from a release zip. Outside that layout, point it explicitly:

```pwsh
$env:SYNCLITE_NATIVE_LIB = "C:\path\to\libsynclite_oss.dll"
# or, equivalently:
$env:SYNCLITE_NATIVE_DIR = "C:\path\to\synclite\lib\native"
python synclite_quickstart.py
```

## 2. `synclite_rusqlite*.py`, `synclite_streaming.py`, `synclite_duckdb*.py` — future API preview

These five samples target the upcoming **`synclite-logger-python`**
package — a PyO3 wheel that will offer the same rich `Connection` /
`Statement` / `await_sync` surface as the Rust crate, plus DB-API 2.0,
SyncLiteStore, SyncLiteStream, and Redis / Kafka compatibility layers.

They will NOT run against today's `synclite` ctypes wrapper — they are
checked in as the canonical reference for what the future Python API
looks like, mirroring the corresponding Rust examples in
`synclite-logger-rust/crates/synclite/examples/`.

| Sample                            | Mirrors Rust example         | Device type     |
| --------------------------------- | ---------------------------- | --------------- |
| `synclite_rusqlite.py`            | `synclite_rusqlite.rs`       | `SQLITE`        |
| `synclite_rusqlite_store.py`      | `synclite_rusqlite_store.rs` | `SQLITE_STORE`  |
| `synclite_streaming.py`           | `synclite_streaming.rs`      | `STREAMING`     |
| `synclite_duckdb.py`              | `synclite_duckdb.rs`         | `DUCKDB`        |
| `synclite_duckdb_store.py`        | `synclite_duckdb_store.rs`   | `DUCKDB_STORE`  |

## Future API shape (preview, not yet runnable)

```python
import synclite as sl  # via the upcoming synclite-logger-python wheel

sl.initialize(
    device_type="SQLITE",
    device_name="sampledevice",
    db_path="myapp.db",
    destination=sl.DestinationOptions(
        dst_type="POSTGRES",
        dst_connection_string="postgresql://user:pw@localhost:5432/syncdb",
        dst_database="syncdb",
        dst_schema="public",
    ),
)

conn = sl.Connection.open("myapp.db")
conn.execute("CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)")

stmt = conn.prepare("INSERT INTO t(id, name) VALUES(?, ?)")
stmt.execute([1, "Alice"])
stmt.add_batch([2, "Bob"])
stmt.add_batch([3, "Carol"])
stmt.execute_batch()

for row in conn.query("SELECT id, name FROM t ORDER BY id"):
    print(row)

conn.commit()
conn.flush()
sl.await_sync("myapp.db", 30.0)
conn.close()
```

`Connection` is the SQLite-family connection (txn / store / streaming).
`DuckDBConnection` is the DuckDB-family equivalent. Both use the same
`execute` / `query` / `prepare` / `commit` / `rollback` / `flush` /
`close` surface as the Rust wrapper crate.
