# SyncLite Python samples

[`core/synclite_rusqlite_postgres.py`](core/synclite_rusqlite_postgres.py) — local SQLite app whose every change is replicated to PostgreSQL by the in-process consolidator. Drives the SyncLite Rust runtime via the [`synclite`](https://pypi.org/) PyO3 wheel — no JVM, no jar.

Top-of-file comments show where to flip **sync mode** (`REPLICATION` ↔ `CONSOLIDATION` — see [../README.md § Sync modes](../README.md#sync-modes-replication-vs-consolidation)) and swap connection settings.

## Quickest start — install from PyPI

```bash
pip install synclite==1.1.0
```

Confirm that the interpreter running the sample has the required version:

```bash
python -c "import synclite; print(synclite.__version__)"
```

The DB-API sample requires `1.1.0` or newer because `synclite.dbapi2` was
added there. If this prints `1.0.0`, upgrade using `python -m pip` rather than
bare `pip` so the package is installed into the same interpreter:

```bash
python -m pip install --upgrade synclite==1.1.0
```

That's it — the published `synclite` wheel is self-contained (bundles its native runtime + DuckDB) and installs on Linux (`manylinux_2_28` x86_64 / aarch64), Windows (`win_amd64`), and macOS with no repo checkout and no Rust toolchain. Then skip straight to [step 2](#2-install-psycopg-for-the-post-sync-postgres-verification) to add the Postgres client and run the sample.

Prefer to run entirely offline from an extracted release zip? Use [Run from the release zip](#run-from-the-release-zip) below instead.

## API-layer samples

The examples are organized by the application-facing Python API:

| Folder | Sample | API |
| --- | --- | --- |
| `core` | [synclite_rusqlite_postgres.py](core/synclite_rusqlite_postgres.py) | Direct SyncLite `Connection` / `Statement` API |
| `dbapi` | [synclite_dbapi_postgres.py](dbapi/synclite_dbapi_postgres.py) | PEP 249 `synclite.dbapi2` API |
| `sqlalchemy` | [synclite_sqlalchemy_postgres.py](sqlalchemy/synclite_sqlalchemy_postgres.py) | SQLAlchemy `sqlite+synclite` dialect |

The three samples use the same local SQLite CRUD flow and PostgreSQL
destination. Each uses device name `sampledevice`, matching the Java and
other language samples, with a separate local database file. Device names
must contain 1–64 ASCII letters or digits only; underscores and hyphens are
not allowed. Database filenames may contain underscores.

Only the application API changes. For the DB-API sample, use
the normal cursor methods. For the SQLAlchemy sample, install the optional
integration first:

```pwsh
python core\synclite_rusqlite_postgres.py
python dbapi\synclite_dbapi_postgres.py
```

```pwsh
pip install "synclite[sqlalchemy]"
python sqlalchemy\synclite_sqlalchemy_postgres.py
```

The SQLAlchemy URL connects to **local SQLite** through SyncLite's logged
driver; the PostgreSQL URL is only the replication destination. SQLAlchemy
commits locally, so `await_sync` remains separate from `engine.begin()`.

The DB-API connection context commits when `with conn:` exits. Call `flush()`
and `await_sync()` only after that block; flushing inside an active transaction
raises `ProgrammingError` to prevent publishing uncommitted segments.

## Run from the release zip

You are already in `sample-apps/python/` of an extracted release. The release ships the `synclite` wheel under [`../../lib/python/`](../../lib/python/).

### 1. Install the bundled wheel

```pwsh
pip install ..\..\lib\python\synclite-1.1.0-cp38-abi3-win_amd64.whl
```

> The release zip ships a Windows `cp38-abi3` wheel. On Linux / macOS, see [Developing against the repo](#developing-against-the-repo) below to build a wheel from the bundled Rust source under [`../../lib/rust/synclite-source/`](../../lib/rust/synclite-source/).

### 2. Install `psycopg` (for the post-sync Postgres verification)

```pwsh
pip install "psycopg[binary]"
```

The `[binary]` extra bundles `libpq`, so this works out of the box without a separate PostgreSQL client install. If `psycopg` is missing the sample still runs the local flow and just skips the `[POSTGRES ...]` verification block.

### 3. Pre-create the Postgres database (one-time)

```sql
CREATE DATABASE syncdb;
```

Defaults: `postgresql://postgres:postgres@localhost:5432/syncdb`, schema `syncschema` (auto-created by the consolidator on first run). Edit `POSTGRES_CONN` at the top of the `.py` to override.

### 4. Run

```pwsh
python core\synclite_rusqlite_postgres.py
```

Safe to rerun — each table is `DROP TABLE IF EXISTS`'d before being recreated.

## What you'll see

Three flows executed locally on SQLite, each step printing a `[LOCAL ...]` banner:

1. **users** — `INSERT` / `UPDATE` / batched `INSERT`.
2. **products** — `ALTER TABLE ADD / RENAME / DROP COLUMN`.
3. **orders → orders_archive** — `ALTER TABLE RENAME TO`.

Then `synclite.await_sync` blocks until the in-process shipper + consolidator have drained to Postgres, and a `[POSTGRES …]` block reconnects with `psycopg` and prints the same rows + same schema from the destination.

## Troubleshooting

- **`ModuleNotFoundError: No module named 'synclite'`** — re-run step 1.
- **`ImportError: cannot import name 'dbapi2' from 'synclite'`** — an older
	SyncLite package is installed. Run `python -m pip install --upgrade
	synclite==1.1.0`, verify `synclite.__version__`, and rerun the sample.
- **`ModuleNotFoundError: No module named 'psycopg'`** — `pip install "psycopg[binary]"`, or ignore (sample skips verification).
- **Nothing landed on Postgres** — check the trace files documented in [../README.md § Where do the samples write files?](../README.md#where-do-the-samples-write-files).

---

## Developing against the repo

If you're working from a `synclite` repo checkout instead of an extracted release, build a fresh wheel from source:

```pwsh
pip install maturin
cd ..\..\synclite-logger-rust\python
maturin develop --release
```

This compiles `crates/logger/bindings-python` and installs the `synclite` package into the active virtual environment for any platform (Windows / Linux / macOS / arm64). Re-run after pulling new commits.
