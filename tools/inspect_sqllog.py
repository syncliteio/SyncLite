import sqlite3
import sys
from pathlib import Path

if len(sys.argv) < 2:
    print("Usage: inspect_sqllog.py <path>")
    sys.exit(2)

p = Path(sys.argv[1])
print(f"Inspecting: {p}")
if not p.exists():
    print("File not found")
    sys.exit(1)

conn = sqlite3.connect(str(p))
cur = conn.cursor()

print('\nPRAGMA database_list:')
for row in cur.execute("PRAGMA database_list"): 
    print(row)

print('\nTables:')
for row in cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"): 
    print('-', row[0])

# Try common tables
for tbl in ('synclite_txn','commandlog','cdclog','txn'):
    try:
        cnt = cur.execute(f"SELECT count(*) FROM {tbl}").fetchone()[0]
        print(f"{tbl}: rows={cnt}")
        if cnt > 0:
            print(f"Last 5 rows from {tbl}:")
            for r in cur.execute(f"SELECT * FROM {tbl} ORDER BY rowid DESC LIMIT 5"):
                print(' ', r)
    except sqlite3.Error:
        pass

# Search for commits in commandlog or cdclog sql
print('\nSample SQL statements (first 20):')
try:
    for r in cur.execute("SELECT sql FROM commandlog WHERE sql IS NOT NULL ORDER BY rowid LIMIT 20"):
        print(' ', r[0])
except sqlite3.Error:
    pass

conn.close()
