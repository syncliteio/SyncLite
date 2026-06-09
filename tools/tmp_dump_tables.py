import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
cur = c.cursor()
for t in sys.argv[2:]:
    print(f"=== {t} ===")
    cur.execute(f"select count(*) from \"{t}\"")
    print("count:", cur.fetchone()[0])
    cur.execute(f"select * from \"{t}\" limit 5")
    for r in cur.fetchall():
        print(" ", r)
