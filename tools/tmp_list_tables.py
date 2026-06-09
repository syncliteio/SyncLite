import sqlite3, sys
p = sys.argv[1]
c = sqlite3.connect(p)
print("Tables in", p)
for r in c.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
    print(" ", r[0])
c.close()
