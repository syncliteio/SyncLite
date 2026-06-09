import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
cur = c.cursor()
cur.execute("select name from sqlite_master where type='table'")
tables = [r[0] for r in cur.fetchall()]
print("TABLES:", tables)
for t in tables:
    cur.execute(f"select count(*) from \"{t}\"")
    print(f"  {t}: {cur.fetchone()[0]} rows")
    cur.execute(f"select * from \"{t}\" limit 3")
    for row in cur.fetchall():
        print("   ", row)
