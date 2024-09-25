1. Go to the directory synclite-platform-<version>\tools\synclite-db.

2. Check the configurations in synclite-db.conf and adjust them as per your needs.

3. Run 

```synclite-db.bat --config synclite-db.conf``` ( OR ```synclite-db.sh --config synclite-db.conf``` on linux). 

This starts the SyncLite DB server listening at the specified address.

4. An application in your favourite programming language can establish a connection with the SyncLite DB server at the specified address and send requests in JSON format as below. Following request response workflow demonstrates usage of SyncLiteDB.

- Connect and initialize a device

	Request

```
	{
		"db-type" : "SQLITE"
		"db-path" : "C:\synclite\users\bob\synclite\job1\test.db"
		"synclite-logger-config" : "C:\synclite\users\bob\synclite\job1\synclite_logger.conf"
		"sql" : "initialize"
	}
```

 	Response from Server

```
	{
		"result" : true
		"message" : "Database initialized successfully"
		"synclite-logger-config" : "C:\synclite\users\bob\synclite\job1\synclite_logger.conf"
	}
```

- Send a sql command (without any arguments) to create a table

	Request

```
	{
		"result" : true
		"db-path" : "C:\synclite\users\bob\synclite\job1\test.db"
		"sql" : "CREATE TABLE IF NOT EXISTS(a INT, b INT)"
	}
```

 	Response from Server
  
```
	{
		"result" : "true"
		"message" : "Update executed successfully, rows affected: 0"
	}
```

- Send a request to perform a batched insert on the created table, passing a JSON array as a batch/arguments.  

	Request

```
	{
		"db-path" : "C:\synclite\users\bob\synclite\job1\test.db"
		"sql" : "INSERT INTO t1(a,b) VALUES(?, ?)"
		"arguments" : [[1, "one"], [2, "two"]]
	}
```

	Response from Server

```
	{
		"result" : "true"
		"message" : "Batch executed successfully, rows affected: 2"
	}
```

-Send a request to begin a transaction on database

	Request

```
	{
		"db-path" : "C:\synclite\users\bob\synclite\job1\test.db"
	   	"sql" : "begin"
	}
```

 	Response from Server

```
	{
		"result" : "true"
		"message" : "Transaction started successfully"
		"txn-handle": "f47ac10b-58cc-4372-a567-0e02b2c3d479"
	}
```

- Send a request to execute a sql inside a started transaction

	Request

```
	{
		"db-path" : "C:\synclite\users\bob\synclite\job1\test.db"
		"sql" : "INSERT INTO t1(a,b) VALUES(?, ?)"
		"txn-handle": "f47ac10b-58cc-4372-a567-0e02b2c3d479"
		"arguments" : [[3, "three"], [4, "four"]]
	}
```

 	Response from Server

```
	{
		"result" : "true"
		"message" : "Batch executed successfully, rows affected: 2"
	}
```

- Send a request to commit a transaction

 	Request

```
	{
		"db-path" : "C:\synclite\users\bob\synclite\job1\test.db"
		"txn-handle": "f47ac10b-58cc-4372-a567-0e02b2c3d479"
		"sql" : "commit"
	}
```

 	Response from Server

```
	{
		"result" : "true"
		"message" : "Transaction committed successfully"
	}
```

- Send a request to close database Request

	Request

```
	{
	   	"db-path" : "C:\synclite\users\bob\synclite\job1\test.db"
	   	"sql" : "close"
	}
```

 	Response from Server

```	
	{
		"result" : "true"
		"message" : "Database closed successfully"
	}
```	
	
5. Refer code samples in various programming languages : Java, Python, C#, C++, Go, Rust, Ruby, Node.js, implementing BELOW 6 APIS which you can copy and readily use to connect to SyncLiteDB in your applications.

- initializeDB
- beginTransaction
- commitTransaction
- rollbackTransaction
- executeSQL
- closeDB
