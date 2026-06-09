import sqlite3, sys
p = sys.argv[1]
c = sqlite3.connect(p)
print("File:", p)
for t in ("cdclog", "cdclog_schemas", "metadata"):
    try:
        n = c.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        print(f"  {t}: {n} rows")
        for r in c.execute(f"SELECT * FROM {t} LIMIT 5"):
            print("    ", r)
    except Exception as e:
        print(f"  {t}: ERR {e}")
c.close()
