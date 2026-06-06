# SyncLite Logger — Python Samples

Python samples that drive the SyncLite **Rust** runtime through the
[`synclite`](../../../synclite-logger-rust/python/) PyO3 bindings.

Each sample is a 1:1 mirror of the canonical Rust example in
`synclite-logger-rust/crates/synclite/examples/` — same `Connection` /
`Statement` API, same call sequence, just Python syntax.

No JVM, no JAR, no `jaydebeapi` / `jpype` bridge.

## Two ways to install the `synclite` Python package

### Option A — build the bindings from source

Useful when you have the platform repo checked out (recommended for
contributors and pre-release tracking).

```pwsh
pip install maturin
cd ..\..\..\synclite-logger-rust\python
maturin develop --release
```

This compiles `crates/logger/bindings-python` (cdylib `_native`) and
installs the `synclite` package into the active environment.

### Option B — install a prebuilt wheel

Useful when you just want to run / embed SyncLite without a Rust
toolchain. Once a SyncLite Python wheel has been published (or built
once with `maturin build --release`), install it directly:

```pwsh
# from PyPI (when published):
pip install synclite

# or from a locally-built wheel:
pip install ..\..\..\synclite-logger-rust\target\wheels\synclite-*.whl
```

Both options install the same `synclite` package — the samples below
work unchanged against either.

## Run a sample

```pwsh
python synclite_rusqlite.py
```

| Sample                            | Mirrors Rust example         | Device type     |
| --------------------------------- | ---------------------------- | --------------- |
| `synclite_rusqlite.py`            | `synclite_rusqlite.rs`       | `SQLITE`        |
| `synclite_rusqlite_store.py`      | `synclite_rusqlite_store.rs` | `SQLITE_STORE`  |
| `synclite_streaming.py`           | `synclite_streaming.rs`      | `STREAMING`     |
| `synclite_duckdb.py`              | `synclite_duckdb.rs`         | `DUCKDB`        |
| `synclite_duckdb_store.py`        | `synclite_duckdb_store.rs`   | `DUCKDB_STORE`  |

## API shape

```python
import synclite as sl

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
