import jaydebeapi

props = {
  "config": "synclite_logger.conf",
  "device-name" : "derby1"
}
conn = jaydebeapi.connect("io.synclite.logger.Derby",
                           "jdbc:synclite_derby:c:\\synclite\\python\\data\\test_derby.db",
                           props,
                           "synclite-logger-extended-<version>.jar",)
                           
curs = conn.cursor()

#Example of executing a DDL : CEATE TABLE. 
#You can execute other DDL operations : DROP TABLE, ALTER TABLE, RENAME TABLE.
curs.execute('CREATE TABLE feedback(rating INT, comment TEXT)')

#Example of performing basic DML operations INSERT/UPDATE/DELETE
curs.execute("insert into feedback values (3, 'Good product')")

#Example of setting Auto commit OFF to implement transactional semantics
conn.jconn.setAutoCommit(False)
curs.execute("update feedback set comment = 'Better product' where rating = 3")
curs.execute("insert into feedback values (1, 'Poor product')")
curs.execute("delete from feedback where rating = 1")
conn.commit()
conn.jconn.setAutoCommit(True)


#Example of Prepared Statement functionality for bulk insert.
args = [[4, 'Excellent product'],[5, 'Outstanding product']]
curs.executemany("insert into feedback values (?, ?)", args)

#Close SyncLite database/device cleanly.
curs.execute("close database c:\\synclite\\python\\data\\test_derby.db");

#You can also close all open databases in a single SQL : CLOSE ALL DATABASES
