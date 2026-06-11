"""SyncLite Python quickstart — honest, working sample against today's C ABI.

Drives the SyncLite Rust runtime through the thin ``synclite`` ctypes
wrapper that ships in ``lib/python/synclite.py``. This sample uses the
real seven-function C ABI (``synclite-bindings-c``) shipped in
``lib/native/`` and works on any CPython 3.8+ with no extra build step.

For the richer ``Connection`` / ``Statement`` / ``await_sync`` API
referenced in the other Python samples here, see the upcoming
``synclite-logger-python`` package (PyO3 wheel).
"""

from __future__ import annotations

import os
from pathlib import Path

# Make ``synclite.py`` importable when running from the release-zip layout
# (``sample-apps/python/...`` with the wrapper at ``lib/python/synclite.py``).
import sys
for parent in [Path(__file__).resolve().parent, *Path(__file__).resolve().parents]:
    cand = parent / "lib" / "python"
    if (cand / "synclite.py").is_file():
        sys.path.insert(0, str(cand))
        break

import synclite as sl  # noqa: E402

CONF_PATH = "synclite_logger.conf"
DB_PATH   = "sample_python_sqlite.db"


def write_conf() -> None:
    """Emit a minimal SQLite-device config that ships to PostgreSQL.

    Adjust ``dst-*`` for your destination, or strip them out for a local-
    only device (every write still produces a durable change log on disk).
    """
    Path(CONF_PATH).write_text(
        "device-name=sample-python\n"
        "db-engine=SQLITE\n"
        "device-type=SQLITE\n"
        f"db-path={DB_PATH}\n"
        "local-data-stage-directory=synclite-stage\n"
        "\n"
        "dst-type=POSTGRES\n"
        "dst-connection-string=postgresql://postgres:postgres@localhost:5432/syncdb\n"
        "dst-database=syncdb\n"
        "dst-schema=syncschema\n"
        "dst-sync-mode=CONSOLIDATION\n",
        encoding="utf-8",
    )


def sql_quote(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def main() -> int:
    write_conf()

    # Open the runtime from the config file. Use as a context manager so
    # the native handle is freed even on exceptions.
    with sl.Runtime.open_config(CONF_PATH) as rt:
        rt.log_sql("DROP TABLE IF EXISTS users")
        rt.log_sql(
            "CREATE TABLE IF NOT EXISTS users("
            " id INTEGER PRIMARY KEY, name TEXT, score INTEGER)"
        )

        # Today's C ABI logs SQL strings only — no parameter binding —
        # so values are inlined here. The upcoming synclite-logger-python
        # package will offer the parameterised Connection / Statement API.
        rt.log_many([
            f"INSERT INTO users(id, name, score) VALUES(1, {sql_quote('Alice')}, 100)",
            f"INSERT INTO users(id, name, score) VALUES(2, {sql_quote('Bob')},   200)",
            f"UPDATE users SET score = 250 WHERE name = {sql_quote('Bob')}",
        ])
        rt.commit()

        rt.log_many([
            f"INSERT INTO users(id, name, score) VALUES(3, {sql_quote('Carol')}, 300)",
            f"INSERT INTO users(id, name, score) VALUES(4, {sql_quote('Dave')},  400)",
        ])
        rt.commit()

        # Roll the active log segment so the in-process shipper can pick
        # it up. Apps normally just keep writing; SyncLite ships changes
        # asynchronously in the background.
        rt.flush_log()

    print(f"[OK] wrote 4 rows to {DB_PATH}; change log in synclite-stage/")
    print("[OK] runtime closed; background shipper will drain to destination.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
