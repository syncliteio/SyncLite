import sqlite3
from pathlib import Path

p = Path(r"c:\Users\arati\synclite\test\workDir\synclite-demo-77c48e63-aaf4-4078-bc8e-fe2cc087ffc6\synclite_device_statistics.db")
print(f"Inspecting: {p}")
conn = sqlite3.connect(str(p))
cur = conn.cursor()
print("Tables:")
for row in cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
    print('-', row[0])
    
print("\nDevice statistics:")
for row in cur.execute("SELECT * FROM device_statistics"):
    print(row)

print("\nTable statistics rows:")
for row in cur.execute("SELECT * FROM table_statistics"):
    print(row)
conn.close()
