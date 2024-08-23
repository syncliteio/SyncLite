import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import io.synclite.logger.*;

public class SyncLiteSQLiteDeviceApp {

	public static void main(String[] args) throws ClassNotFoundException, SQLException {		
		appStartup(); //Code to be executed on your app startup to initialize your SyncLite devices.
		SyncLiteSQLiteDeviceApp app = new SyncLiteSQLiteDeviceApp();
		app.myAppBusinessLogic(); //Your app business logic that can do arbitrary DB operations on a SyncLite device using JDBC
	}

	public static void appStartup() throws SQLException, ClassNotFoundException {
		Class.forName("io.synclite.logger.SQLite");
		Path dbPath = Path.of("test_sqlite.db");
		SQLite.initialize(dbPath, Path.of("synclite_logger.conf"));
	}	
	
	public void myAppBusinessLogic() throws SQLException {
		//
		//Some application business logic
		//
		//Perform some database operations		
		try (Connection conn = DriverManager.getConnection("jdbc:synclite_sqlite:test_sqlite.db")) {
			try (Statement stmt = conn.createStatement()) { 
				//Example of executing a DDL : CREATE TABLE. 
				//You can execute other DDL operations : DROP TABLE, ALTER TABLE, RENAME TABLE.
				stmt.execute("CREATE TABLE IF NOT EXISTS feedback(rating INT, comment TEXT)");
				
				//Example of performing INSERT
				stmt.execute("INSERT INTO feedback VALUES(3, 'Good product')");				
			}
			
			//Example of setting Auto commit OFF to implement transactional semantics
			conn.setAutoCommit(false);
			try (Statement stmt = conn.createStatement()) { 
				//Example of performing basic DML operations INSERT/UPDATE/DELETE
				stmt.execute("UPDATE feedback SET comment = 'Better product' WHERE rating = 3");
				stmt.execute("INSERT INTO feedback VALUES (1, 'Poor product')");
				stmt.execute("DELETE FROM feedback WHERE rating = 1");
			}
			conn.commit();
			conn.setAutoCommit(true);
			
			//Example of Prepared Statement functionality for bulk insert.			
			try(PreparedStatement pstmt = conn.prepareStatement("INSERT INTO feedback VALUES(?, ?)")) {
				pstmt.setInt(1, 4);
				pstmt.setString(2, "Excellent Product");
				pstmt.addBatch();
				
				pstmt.setInt(1, 5);
				pstmt.setString(2, "Outstanding Product");
				pstmt.addBatch();
				
				pstmt.executeBatch();			
			}
		}
		//Close SyncLite database/device cleanly.
		SQLite.closeDevice(Path.of("test_sqlite.db"));
		//You can also close all open databases in a single SQL : CLOSE ALL DATABASES
	}	
}
