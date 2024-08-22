import jaydebeapi
props = {
  "config": "synclite_logger.conf",
  "device-name" : "h2app1"
}
conn = jaydebeapi.connect("io.synclite.logger.H2Appender",
                           "jdbc:synclite_h2_appender:c:\\synclite\\python\\data\\test_h2_appender.db",
                           props,
                           "synclite-logger-extended-<version>.jar",)

curs = conn.cursor()

#Example of executing a DDL : CEATE TABLE. 
#You can execute other DDL operations : DROP TABLE, ALTER TABLE, RENAME TABLE.
curs.execute('CREATE TABLE IF NOT EXISTS feedback(rating INT, comment TEXT)')

#Example of Prepared Statement functionality for bulk insert.
args = [[4, 'Excellent product'],[5, 'Outstanding product']]
curs.executemany("insert into feedback values (?, ?)", args)

#Close SyncLite database/device cleanly.
curs.execute("close database c:\\synclite\\python\\data\\test_h2_appender.db");

#You can also close all open databases in a single SQL : CLOSE ALL DATABASES
