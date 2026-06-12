# SyncLite Python samples

These mirror the Rust samples in `../rust/` and the C++ samples in
`../cpp/` — same shapes, same flows, same destinations — built on the
[`synclite`](../../../synclite-logger-rust/python/) Python package, a
PyO3 binding over the SyncLite Rust runtime. The Python API matches the
Rust crate and the C++ wrapper one-for-one: `Connection`, `Statement`,
`DuckDBConnection`, `DuckDBStatement`, plus module-level `initialize`
and `await_sync`.

## Layout

| file                          | mirrors                      | device type     |
| ----------------------------- | ---------------------------- | --------------- |
| `synclite_rusqlite.py`        | `synclite_rusqlite.rs`       | `SQLITE`        |
| `synclite_rusqlite_store.py`  | `synclite_rusqlite_store.rs` | `SQLITE_STORE`  |
| `synclite_streaming.py`       | `synclite_streaming.rs`      | `STREAMING`     |
| `synclite_duckdb.py`          | `synclite_duckdb.rs`         | `DUCKDB`        |
| `synclite_duckdb_store.py`    | `synclite_duckdb_store.rs`   | `DUCKDB_STORE`  |

## Install the `synclite` package

You need the `synclite` Python package installed in the active
environment. You can either **(A)** build it from source against the
in-tree Rust workspace, or **(B)** install a published wheel.

### Option A — build from source (recommended for contributors)

Useful when you have the platform repo checked out and want to track
in-tree changes to the Rust runtime.

```pwsh
pip install maturin
cd ..\..\..\synclite-logger-rust\python
maturin develop --release
```

This compiles `crates/logger/bindings-python` and installs the
`synclite` package (with the `_native` cdylib) into the active virtual
environment. Re-run after pulling new commits.

### Option B — install a published wheel

```pwsh
pip install synclite
```

A published PyPI release is on the roadmap; until then Option A is the
canonical install path. Both options expose the exact same
`synclite::` API — the sample sources run unchanged against either.

## Run a sample

PostgreSQL destination prereq (matches the marquee samples):

```sql
CREATE DATABASE syncdb;
\c syncdb
CREATE SCHEMA syncschema;
```

```pwsh
cd synclite-code-samples\synclite-runtime\python
python synclite_rusqlite.py
```

Each sample prints rows locally, then `await_sync` blocks until the
in-process shipper + embedded consolidator have drained the change log
to the destination — same checkpoint semantics as the Rust and C++
samples.

## API surface at a glance

Matches the Rust crate and the C++ header-only wrapper line-for-line:

```python
import synclite as sl

sl.initialize(
    device_type="SQLITE",
    device_name="sampledevice",
    db_path="myapp.db",
    destination=sl.DestinationOptions(
        dst_type="POSTGRES",
        dst_connection_string="postgresql://postgres:postgres@localhost:5432/syncdb",
        dst_database="syncdb",
        dst_schema="syncschema",
        dst_sync_mode="CONSOLIDATION",
    ),
)

with sl.Connection.open("myapp.db") as conn:
    conn.execute("CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)")

    # unbatched
    stmt = conn.prepare("INSERT INTO t(id, name) VALUES(?, ?)")
    stmt.execute([1, "Alice"])
    stmt.execute([2, "Bob"])

    # batched
    stmt = conn.prepare("INSERT INTO t(id, name) VALUES(?, ?)")
    stmt.add_batch([3, "Carol"])
    stmt.add_batch([4, "Dave"])
    stmt.execute_batch()

    for row in conn.query("SELECT id, name FROM t ORDER BY id"):
        print(row)

    conn.commit()
    conn.flush()

sl.await_sync("myapp.db", 30.0)
```

For DuckDB, swap `Connection` for `DuckDBConnection` and use
`device_type="DUCKDB"`. For STORE / STREAMING devices, write a config
file with `device-type=SQLITE_STORE` (or `STREAMING`) and open with
`Connection.open_with_config(conf_path)`.

See the [`synclite` package README](../../../synclite-logger-rust/python/README.md)
for the full type reference (parameter conversion, return shapes,
enums accepted as case-insensitive strings).
