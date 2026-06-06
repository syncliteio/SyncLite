import sqlite3
import sys
from pathlib import Path

if len(sys.argv) < 2:
    print("Usage: tmp_inspect_meta.py <metadata_db>")
    sys.exit(2)

p = Path(sys.argv[1])
print(f"Inspecting: {p}")
if not p.exists():
    print("File not found")
    sys.exit(1)

conn = sqlite3.connect(str(p))
cur = conn.cursor()

print("\nTables:")
tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
for t in tables:
    print("-", t)

for t in ("events", "state", "staged_paths"):
    if t in tables:
        print(f"\nLast rows from {t}:")
        try:
            rows = cur.execute(f"SELECT * FROM {t} ORDER BY rowid DESC LIMIT 50").fetchall()
            for r in rows:
                print(" ", r)
        except Exception as e:
            print("  error:", e)

conn.close()
