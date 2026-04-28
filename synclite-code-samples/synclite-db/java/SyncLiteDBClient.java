package sampleapp;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.SQLException;
import java.util.Base64;
import java.util.UUID;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.security.MessageDigest;

import org.json.JSONArray;
import org.json.JSONObject;

/*
*
* ===========================================================
  Note: 
* ===========================================================
Add org.json library as dependency
	
	<dependency>
	    <groupId>org.json</groupId>
	    <artifactId>json</artifactId>
	    <version>20240303</version>
	</dependency>


This source file implements following APIs to connect to SyncLiteDB:

1. initializeDB : Initialize the given database/device of specified type (SQLITE, DUCKDB, DERBY, H2, HYPERSQL, SQLITE_APPENDER, DUCKDB_APPENDER, DERBY_APPENDER, H2_APPENDER, HYPERSQL_APPENDER, STREAMING) at the specified path. 
2. beginTransaction: Begin a transaction on specified database, returning a transaction handle
3. executeSQL: Execute specified SQL with (optional arguments for batch operations with prepared statements), on the specified database.
4. commitTransction: Commit the transaction with given transaction handle
5. rollbackTransaction: Rollback the transaction with given transaction handle
6. closeDB: Close the given database.

You can copy these APIs in your application to get started with SyncLite DB. 


The test code attempts the following operations:

1. Intialize a database of type SQLITE
2. Begin a transaction

sql: begin

3. Create a table

 sql : CREATE TABLE t1(a int, b text)

4. Insert 2 records using an INSERT prepared statement and passing a JSON array of arrays( with each inner array representing the bind paramemeters for each record) as a batch of arguments.

sql:
INSERT INTO t1 (a, b) VALUES(?, ?)

arguments: 

[
	[1, "one"]
	[2, "two]
]

5. Commit transaction:

sql: commit

6. Select records from t1

sql:
 SELECT a, b FROM t1

Response containing resultSet as a a JSON array (each record in JSON array holding a JSON object representing a table record as a map of <ColumnName, ColumnValue> pairs
   [
        {
            "a": 1,
            "b": "one"
        },
        {
            "a": 2,
            "b": "two"
        }
    ]

7. Drop table t1

sql: drop table t1

8. Close database
 

*/


public class SyncLiteDBClient {

	public static class SyncLiteDBResult {
		public boolean result;
		public String message;
		public JSONArray resultSet;
		public String txnHandle;
		public String resultsetHandle;
		public Boolean hasMore;
                public JSONArray columnMetadata;
        }

        private static SyncLiteDBResult toResult(JSONObject jsonResponse) {
                SyncLiteDBResult dbResult = new SyncLiteDBResult();
                dbResult.result = jsonResponse.optBoolean("result");
                dbResult.message = jsonResponse.optString("message");
                if (jsonResponse.has("resultset")) {
                        dbResult.resultSet = jsonResponse.getJSONArray("resultset");
                }
                if (jsonResponse.has("txn-handle")) {
                        dbResult.txnHandle = jsonResponse.optString("txn-handle", null);
                }
                if (jsonResponse.has("resultset-handle")) {
                        dbResult.resultsetHandle = jsonResponse.optString("resultset-handle", null);
                }
                if (jsonResponse.has("has-more")) {
                        dbResult.hasMore = Boolean.valueOf(jsonResponse.optBoolean("has-more"));
                }
                if (jsonResponse.has("resultset-metadata")) {
                        dbResult.columnMetadata = jsonResponse.getJSONArray("resultset-metadata");
	private static String sha256Hex(String value) throws Exception {
		MessageDigest digest = MessageDigest.getInstance("SHA-256");
		byte[] hash = digest.digest(value.getBytes(StandardCharsets.UTF_8));
		StringBuilder builder = new StringBuilder();
		for (byte b : hash) {
			builder.append(String.format("%02x", b));
		}
		return builder.toString();
	}

	private static String sign(String secret, String payload) throws Exception {
		Mac mac = Mac.getInstance("HmacSHA256");
		mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
		return Base64.getEncoder().encodeToString(mac.doFinal(payload.getBytes(StandardCharsets.UTF_8)));
	}

	public static JSONObject processRequest(JSONObject jsonRequest) throws SQLException {
		JSONObject jsonResponse = null;
		try {
			URL url = new URL(syncLiteDBAddress);

			HttpURLConnection conn = (HttpURLConnection) url.openConnection();

			// Set up connection properties
			conn.setRequestMethod("POST");
			conn.setRequestProperty("Content-Type", "application/json"); // Set content type as JSON
			conn.setDoOutput(true);
			conn.setConnectTimeout(10000);
			conn.setReadTimeout(10000);

			String token = System.getenv("SYNCLITE_DB_AUTH_TOKEN");
			if (token != null && !token.isBlank()) {
				conn.setRequestProperty("X-SyncLite-Token", token);
			}

			String appId = System.getenv("SYNCLITE_DB_APP_ID");
			String appSecret = System.getenv("SYNCLITE_DB_APP_SECRET");
			String payload = jsonRequest.toString();
			if (appId != null && !appId.isBlank() && appSecret != null && !appSecret.isBlank()) {
				String timestamp = String.valueOf(System.currentTimeMillis());
				String nonce = UUID.randomUUID().toString();
				String canonical = "POST\n/\n" + timestamp + "\n" + nonce + "\n" + sha256Hex(payload);
				String signature = sign(appSecret, canonical);

				conn.setRequestProperty("X-SyncLite-App-Id", appId);
				conn.setRequestProperty("X-SyncLite-Timestamp", timestamp);
				conn.setRequestProperty("X-SyncLite-Nonce", nonce);
				conn.setRequestProperty("X-SyncLite-Signature", signature);
			}

			System.out.println("Request JSON: " + jsonRequest.toString(4)); // Pretty print with 4 spaces

			// Send the JSON request
			try (OutputStream os = conn.getOutputStream()) {
				byte[] input = payload.getBytes(StandardCharsets.UTF_8);
				os.write(input, 0, input.length);
			}

			// Get the response code
			int responseCode = conn.getResponseCode();
			System.out.println("Response Code: " + responseCode);

			// If the response code is 200 OK, read the response
			if (responseCode == HttpURLConnection.HTTP_OK || responseCode == HttpURLConnection.HTTP_BAD_REQUEST || responseCode == HttpURLConnection.HTTP_UNAUTHORIZED || responseCode == 413) {
				BufferedReader in;
				if (responseCode == HttpURLConnection.HTTP_OK) {
					in = new BufferedReader(new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8));
				} else {
					in = new BufferedReader(new InputStreamReader(conn.getErrorStream(), StandardCharsets.UTF_8));
				}
				String inputLine;
				StringBuilder response = new StringBuilder();

				while ((inputLine = in.readLine()) != null) {
					response.append(inputLine);
				}
				in.close();

				// Parse the response JSON and print it
				jsonResponse = new JSONObject(response.toString());
				System.out.println("Response JSON: " + jsonResponse.toString(4)); // Pretty print with 4 spaces

				// Access specific fields in the response JSON
				boolean result = jsonResponse.getBoolean("result");
				String message = jsonResponse.getString("message");

				System.out.println("Result: " + result);
				System.out.println("Message: " + message);
			} else {
				throw new SQLException("Failed to get a valid response from the server : " + responseCode);
			}	
		} catch (Exception e) {
			throw new SQLException("Failed to process request : " + e.getMessage(), e);
		}
		return jsonResponse;
	}

	public static SyncLiteDBResult initializeDB(Path dbPath, String dbType, String dbName, Path syncLiteLoggerConfigPath) throws SQLException{
		SyncLiteDBResult dbResult;
		try {
			JSONObject jsonRequest = new JSONObject();
			jsonRequest.put("db-path", dbPath);
			jsonRequest.put("db-type", dbType);
			jsonRequest.put("db-name", dbName);
			if (syncLiteLoggerConfigPath != null) {
				jsonRequest.put("synclite-logger-config", syncLiteLoggerConfigPath);
			}
			jsonRequest.put("sql", "initialize");

			JSONObject jsonRespose = processRequest(jsonRequest);

			dbResult = toResult(jsonRespose);
		} catch (Exception e) {
			throw new SQLException("Failed to initialize DB : " + dbPath + " : " + e.getMessage(), e);
		}
		return dbResult;
	}

	public static SyncLiteDBResult beginTransaction(Path dbPath) throws SQLException {
		SyncLiteDBResult dbResult;
		try {
			JSONObject jsonRequest = new JSONObject();
			jsonRequest.put("db-path", dbPath);
			jsonRequest.put("sql", "begin");

			JSONObject jsonRespose = processRequest(jsonRequest);

			dbResult = toResult(jsonRespose);
		} catch (Exception e) {
			throw new SQLException("Failed to begin transaction on DB : " + dbPath + " : " + e.getMessage(), e);
		}
		return dbResult;
	}

	public static SyncLiteDBResult commitTransaction(Path dbPath, String txnHandle) throws SQLException {
		SyncLiteDBResult dbResult;
		try {
			JSONObject jsonRequest = new JSONObject();
			jsonRequest.put("db-path", dbPath);
			jsonRequest.put("txn-handle", txnHandle);
			jsonRequest.put("sql", "commit");

			JSONObject jsonRespose = processRequest(jsonRequest);

			dbResult = toResult(jsonRespose);
		} catch (Exception e) {
			throw new SQLException("Failed to commit transaction on DB : " + dbPath + " : " + e.getMessage(), e);
		}
		return dbResult;
	}

	public static SyncLiteDBResult rollbackTransaction(Path dbPath, String txnHandle) throws SQLException {
		SyncLiteDBResult dbResult;
		try {
			JSONObject jsonRequest = new JSONObject();
			jsonRequest.put("db-path", dbPath);
			jsonRequest.put("txn-handle", txnHandle);
			jsonRequest.put("sql", "rollback");

			JSONObject jsonRespose = processRequest(jsonRequest);

			dbResult = toResult(jsonRespose);
		} catch (Exception e) {
			throw new SQLException("Failed to rollback trasnaction on DB : " + dbPath + " : " + e.getMessage(), e);
		}
		return dbResult;
	}

	public static SyncLiteDBResult executeSQL(Path dbPath, String txnHandle, String sql, JSONArray arguments) throws SQLException {
                return executeSQL(dbPath, txnHandle, sql, arguments, null, null);
        }

        public static SyncLiteDBResult executeSQL(Path dbPath, String txnHandle, String sql, JSONArray arguments, String dataFormat, Boolean includeMetadata) throws SQLException {
                SyncLiteDBResult dbResult;
                try {
                        JSONObject jsonRequest = new JSONObject();
                        jsonRequest.put("db-path", dbPath);
                        jsonRequest.put("sql", sql);
                        if (txnHandle != null) {
                                jsonRequest.put("txn-handle", txnHandle);
                        }
                        if (arguments != null) {
                                jsonRequest.put("arguments", arguments);
                        }
                        if (dataFormat != null) {
                                jsonRequest.put("resultset-data-format", dataFormat);
                        }
                        if (includeMetadata != null) {
                                jsonRequest.put("resultset-include-metadata", includeMetadata ? "ON" : "OFF");

			JSONObject jsonRespose = processRequest(jsonRequest);

			dbResult = toResult(jsonRespose);
		} catch (Exception e) {
			throw new SQLException("Failed to execute sql on DB : " + dbPath + " : " + e.getMessage(), e);
		}
		return dbResult;
	}

	public static SyncLiteDBResult next(String resultsetHandle, Integer resultsetPaginationSize) throws SQLException {
                return next(resultsetHandle, resultsetPaginationSize, null, null);
        }

        public static SyncLiteDBResult next(String resultsetHandle, Integer resultsetPaginationSize, String dataFormat, Boolean includeMetadata) throws SQLException {
                try {
                        JSONObject jsonRequest = new JSONObject();
                        jsonRequest.put("request-type", "next");
                        jsonRequest.put("resultset-handle", resultsetHandle);
                        if (resultsetPaginationSize != null && resultsetPaginationSize.intValue() > 0) {
                                jsonRequest.put("resultset-pagination-size", resultsetPaginationSize.intValue());
                        }
                        if (dataFormat != null) {
                                jsonRequest.put("resultset-data-format", dataFormat);
                        }
                        if (includeMetadata != null) {
                                jsonRequest.put("resultset-include-metadata", includeMetadata ? "ON" : "OFF");

			JSONObject jsonRespose = processRequest(jsonRequest);
			return toResult(jsonRespose);
		} catch (Exception e) {
			throw new SQLException("Failed to fetch next page for resultset-handle : " + resultsetHandle + " : " + e.getMessage(), e);
		}
	}

	public static SyncLiteDBResult closeDB(Path dbPath) throws SQLException {
		SyncLiteDBResult dbResult;
		try {
			JSONObject jsonRequest = new JSONObject();
			jsonRequest.put("db-path", dbPath);
			jsonRequest.put("sql", "close");

			JSONObject jsonRespose = processRequest(jsonRequest);

			dbResult = toResult(jsonRespose);
		} catch (Exception e) {
			throw new SQLException("Failed to close DB : " + dbPath + " : " + e.getMessage(), e);
		}
		return dbResult;

	}

	public static void main(String[] args) throws IOException, SQLException {

		//Initialize db directory
		createDBDirs();

		Path dbPath = dbDir.resolve("testJava.db");

		//Initialize DB
		System.out.println("========================================================");
		System.out.println("Excecuting initialize DB"); 
		System.out.println("========================================================");
		SyncLiteDBResult r = initializeDB(dbPath, "SQLITE", "testJava", null);
		System.out.println("result : " + r.result);
		System.out.println("message : " + r.message);

		if (r.result == false) {
			System.exit(1);
		}
		System.out.println("========================================================");
	
		
		//Start a transaction
		System.out.println("========================================================");
		System.out.println("Excecuting begin transaction"); 
		System.out.println("========================================================");
		r = beginTransaction(dbPath);
		System.out.println("result : " + r.result);
		System.out.println("message : " + r.message);
		System.out.println("txn-handle: " + r.txnHandle);
		String txnHandle = r.txnHandle;
		if (r.result == false) {
			System.exit(1);
		}
		System.out.println("========================================================");
		
		//Create a Table
		System.out.println("========================================================");
		System.out.println("Excecuting create table"); 
		System.out.println("========================================================");
		r = executeSQL(dbPath, txnHandle, "create table if not exists t1(a int, b text)", null);
		System.out.println("result : " + r.result);
		System.out.println("message : " + r.message);
		if (r.result == false) {
			System.exit(1);
		}
		System.out.println("========================================================");
		
		//Insert Data in a table
		System.out.println("========================================================");
		System.out.println("Excecuting insert into table"); 
		System.out.println("========================================================");
		JSONArray arguments = new JSONArray();
		JSONArray rec1= new JSONArray();
		rec1.put(1);
		rec1.put("one");
		
		JSONArray rec2= new JSONArray();
		rec2.put(2);
		rec2.put("two");

		arguments.put(rec1);
		arguments.put(rec2);

		r = executeSQL(dbPath, txnHandle, "insert into t1 (a,b) values(?, ?)", arguments);
		System.out.println("result : " + r.result);
		System.out.println("message : " + r.message);
		if (r.result == false) {
			System.exit(1);
		}
		System.out.println("========================================================");

		//Commit Transaction
		System.out.println("========================================================");
		System.out.println("Excecuting commit transaction"); 
		System.out.println("========================================================");
		r = commitTransaction(dbPath, txnHandle);
		System.out.println("result : " + r.result);
		System.out.println("message : " + r.message);
		if (r.result == false) {
			System.exit(1);
		}
		System.out.println("========================================================");

//Select from table (JSON format - default, records as {colName: colValue} objects)
                System.out.println("========================================================");
                System.out.println("Excecuting select from table (JSON format)"); 
                System.out.println("========================================================");
                r = executeSQL(dbPath, null, "select a, b from t1", null);
                System.out.println("result : " + r.result);
                System.out.println("message : " + r.message);

                // Print column headers from metadata
                if (r.columnMetadata != null) {
                        StringBuilder header = new StringBuilder();
                        for (int i = 0; i < r.columnMetadata.length(); i++) {
                                if (i > 0) header.append("\t");
                                header.append(r.columnMetadata.getJSONObject(i).getString("label"));
                        }
                        System.out.println(header);
                }
                SyncLiteDBResult current = r;
                while (true) {
                        if (current.resultSet != null) {
                                for (int i = 0; i < current.resultSet.length(); ++i) {
                                        JSONObject rec = current.resultSet.getJSONObject(i);
                                        System.out.println("a = " + rec.get("a") + ", b = " + rec.get("b"));
                                }
                        }
                        if (!Boolean.TRUE.equals(current.hasMore) || current.resultsetHandle == null || current.resultsetHandle.isBlank()) {
                                break;
                        }
                        current = next(current.resultsetHandle, null);
                        if (!current.result) {
                                throw new SQLException("Failed to fetch next page: " + current.message);
                        }
                }
                System.out.println("========================================================");

                //Select from table (DB format - records as value arrays, column order matches metadata)
                System.out.println("========================================================");
                System.out.println("Excecuting select from table (DB format)"); 
                System.out.println("========================================================");
                r = executeSQL(dbPath, null, "select a, b from t1", null, "DB", true);
                System.out.println("result : " + r.result);
                System.out.println("message : " + r.message);

                // Print column headers from metadata
                if (r.columnMetadata != null) {
                        StringBuilder header = new StringBuilder();
                        for (int i = 0; i < r.columnMetadata.length(); i++) {
                                if (i > 0) header.append("\t");
                                header.append(r.columnMetadata.getJSONObject(i).getString("label"));
                        }
                        System.out.println(header);
                }
                current = r;
                while (true) {
                        if (current.resultSet != null) {
                                for (int i = 0; i < current.resultSet.length(); ++i) {
                                        JSONArray row = current.resultSet.getJSONArray(i);
                                        StringBuilder sb = new StringBuilder();
                                        for (int j = 0; j < row.length(); j++) {
                                                if (j > 0) sb.append("\t");
                                                sb.append(row.isNull(j) ? "null" : row.get(j));
                                        }
                                        System.out.println(sb);
                                }
                        }
                        if (!Boolean.TRUE.equals(current.hasMore) || current.resultsetHandle == null || current.resultsetHandle.isBlank()) {
                                break;
                        }
                        current = next(current.resultsetHandle, null, "DB", null);
			if (!current.result) {
				throw new SQLException("Failed to fetch next page: " + current.message);
			}
		}
		System.out.println("========================================================");
		
		//Drop table
		System.out.println("========================================================");
		System.out.println("Excecuting drop table"); 
		System.out.println("========================================================");
		r = executeSQL(dbPath, null, "drop table t1", null);
		System.out.println("result : " + r.result);
		System.out.println("message : " + r.message);

		//Close DB
		System.out.println("========================================================");
		System.out.println("Excecuting close DB"); 
		System.out.println("========================================================");
		r = closeDB(dbPath);
		System.out.println("result : " + r.result);
		System.out.println("message : " + r.message);
		System.out.println("========================================================");

	}

	private static void createDBDirs() throws IOException {
		dbDir = Path.of(System.getProperty("user.home"), "synclite", "job1", "db");        	
		Files.createDirectories(dbDir);
	}

}
