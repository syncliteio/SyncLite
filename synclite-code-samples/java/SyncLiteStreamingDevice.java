/*
 * Copyright (c) 2024 mahendra.chavan@synclite.io, all rights reserved.
 *
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied.  See the License for the specific language governing permissions and limitations
 * under the License.
 *
 */

import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import io.synclite.logger.*;

public class SyncLiteStreamingDeviceApp {

	public static void main(String[] args) throws ClassNotFoundException, SQLException {		
		appStartup(); //Code to be executed on your app startup to initialize your SyncLite devices.
		SyncLiteStreamingDeviceApp app = new SyncLiteStreamingDeviceApp();
		app.myAppBusinessLogic(); //Your app business logic that can do arbitrary DB operations on a SyncLite device using JDBC
	}

	public static void appStartup() throws SQLException, ClassNotFoundException {
		Class.forName("io.synclite.logger.Streaming");
		Path dbPath = Path.of("t_str.db");
		Streaming.initialize(dbPath, Path.of("synclite_logger.conf"));
	}	
	
	public void myAppBusinessLogic() throws SQLException {
		//
		//Some application business logic
		//
		//Perform some database operations		
		try (Connection conn = DriverManager.getConnection("jdbc:synclite_streaming:t_str.db")) {
			try (Statement stmt = conn.createStatement()) { 
				//Example of executing a DDL : CREATE TABLE. 
				//You can execute other DDL operations : DROP TABLE, ALTER TABLE, RENAME TABLE.
				stmt.execute("CREATE TABLE IF NOT EXISTS feedback(rating INT, comment TEXT)");				
			}			
		
			//Example of Prepared Statement functionality for bulk insert.
			//Note that Streaming Device only supports DDL, INSERT INTO DML operations.
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
		Streaming.closeDevice(Path.of("t_str.db"));
		//You can also close all open databases/devices in a single SQL : CLOSE ALL DATABASES
	}	
}
