using System;
using System.IO;
using System.Net;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

/*

* ===========================================================
  Note: 
* ===========================================================
Install packge Newtonsoft.Json : Install-Package Newtonsoft.Json


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

namespace SyncLite
{
    public class SyncLiteDBResult
    {
        public bool Result { get; set; }
        public string Message { get; set; }
        public JArray ResultSet { get; set; }
        public string TxnHandle { get; set; }
    }

    public class SyncLiteDBClient
    {
        private static string syncLiteDBAddress = "http://localhost:5555";
        private static string dbDir;

        public static JObject ProcessRequest(JObject jsonRequest)
        {
            JObject jsonResponse = null;

            try
            {
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(syncLiteDBAddress);
                request.Method = "POST";
                request.ContentType = "application/json";
                request.Timeout = 10000;

                Console.WriteLine("Request JSON: " + jsonRequest.ToString(Formatting.Indented));

                // Send the JSON request
                using (var streamWriter = new StreamWriter(request.GetRequestStream()))
                {
                    string json = jsonRequest.ToString();
                    streamWriter.Write(json);
                    streamWriter.Flush();
                    streamWriter.Close();
                }

                // Get the response
                HttpWebResponse response = (HttpWebResponse)request.GetResponse();
                if (response.StatusCode == HttpStatusCode.OK)
                {
                    using (var streamReader = new StreamReader(response.GetResponseStream()))
                    {
                        string result = streamReader.ReadToEnd();
                        jsonResponse = JObject.Parse(result);
                    }
                    Console.WriteLine("Response JSON: " + jsonResponse.ToString(Formatting.Indented));
                }
                else
                {
                    throw new Exception("Failed to get a valid response from the server : " + response.StatusCode);
                }
            }
            catch (Exception ex)
            {
                throw new Exception("Failed to process request: " + ex.Message, ex);
            }

            return jsonResponse;
        }

        public static SyncLiteDBResult InitializeDB(string dbPath, string dbType, string dbName, string syncLiteLoggerConfigPath = null)
        {
            SyncLiteDBResult dbResult = new SyncLiteDBResult();

            try
            {
                JObject jsonRequest = new JObject
                {
                    { "db-path", dbPath },
                    { "db-type", dbType },
                    { "db-name", dbName },
                    { "sql", "initialize" }
                };

                if (!string.IsNullOrEmpty(syncLiteLoggerConfigPath))
                {
                    jsonRequest["synclite-logger-config"] = syncLiteLoggerConfigPath;
                }

                JObject jsonResponse = ProcessRequest(jsonRequest);

                dbResult.Result = jsonResponse["result"].ToObject<bool>();
                dbResult.Message = jsonResponse["message"].ToString();
            }
            catch (Exception e)
            {
                throw new Exception("Failed to initialize DB: " + dbPath + " : " + e.Message, e);
            }

            return dbResult;
        }

        public static SyncLiteDBResult BeginTransaction(string dbPath)
        {
            SyncLiteDBResult dbResult = new SyncLiteDBResult();

            try
            {
                JObject jsonRequest = new JObject
                {
                    { "db-path", dbPath },
                    { "sql", "begin" }
                };

                JObject jsonResponse = ProcessRequest(jsonRequest);

                dbResult.Result = jsonResponse["result"].ToObject<bool>();
                dbResult.Message = jsonResponse["message"].ToString();
                dbResult.TxnHandle = jsonResponse["txn-handle"].ToString();
            }
            catch (Exception e)
            {
                throw new Exception("Failed to begin transaction on DB: " + dbPath + " : " + e.Message, e);
            }

            return dbResult;
        }

        public static SyncLiteDBResult CommitTransaction(string dbPath, string txnHandle)
        {
            SyncLiteDBResult dbResult = new SyncLiteDBResult();

            try
            {
                JObject jsonRequest = new JObject
                {
                    { "db-path", dbPath },
                    { "txn-handle", txnHandle },
                    { "sql", "commit" }
                };

                JObject jsonResponse = ProcessRequest(jsonRequest);

                dbResult.Result = jsonResponse["result"].ToObject<bool>();
                dbResult.Message = jsonResponse["message"].ToString();
            }
            catch (Exception e)
            {
                throw new Exception("Failed to commit transaction on DB: " + dbPath + " : " + e.Message, e);
            }

            return dbResult;
        }

	public static SyncLiteDBResult RollbackTransaction(string dbPath, string txnHandle)
        {
            SyncLiteDBResult dbResult = new SyncLiteDBResult();

            try
            {
                JObject jsonRequest = new JObject
                {
                    { "db-path", dbPath },
                    { "txn-handle", txnHandle },
                    { "sql", "rollback" }
                };

                JObject jsonResponse = ProcessRequest(jsonRequest);

                dbResult.Result = jsonResponse["result"].ToObject<bool>();
                dbResult.Message = jsonResponse["message"].ToString();
            }
            catch (Exception e)
            {
                throw new Exception("Failed to commit transaction on DB: " + dbPath + " : " + e.Message, e);
            }

            return dbResult;
        }


        public static SyncLiteDBResult ExecuteSQL(string dbPath, string txnHandle, string sql, JArray arguments = null)
        {
            SyncLiteDBResult dbResult = new SyncLiteDBResult();

            try
            {
                JObject jsonRequest = new JObject
                {
                    { "db-path", dbPath },
                    { "sql", sql }
                };

                if (!string.IsNullOrEmpty(txnHandle))
                {
                    jsonRequest["txn-handle"] = txnHandle;
                }

                if (arguments != null)
                {
                    jsonRequest["arguments"] = arguments;
                }

                JObject jsonResponse = ProcessRequest(jsonRequest);

                dbResult.Result = jsonResponse["result"].ToObject<bool>();
                dbResult.Message = jsonResponse["message"].ToString();
                if (jsonResponse["resultset"] != null)
                {
                    dbResult.ResultSet = (JArray)jsonResponse["resultset"];
                }
            }
            catch (Exception e)
            {
                throw new Exception("Failed to execute SQL on DB: " + dbPath + " : " + e.Message, e);
            }

            return dbResult;
        }

        public static void Main(string[] args)
        {
            // Initialize db directory
            CreateDBDirs();

            string dbPath = Path.Combine(dbDir, "testCSharp.db");

            // Initialize DB
            Console.WriteLine("========================================================");
            Console.WriteLine("Executing initialize DB");
            Console.WriteLine("========================================================");
            SyncLiteDBResult r = InitializeDB(dbPath, "SQLITE", "testCSharp");
            Console.WriteLine("Result: " + r.Result);
            Console.WriteLine("Message: " + r.Message);

            if (!r.Result)
            {
                Environment.Exit(1);
            }

            // Start a transaction
            Console.WriteLine("========================================================");
            Console.WriteLine("Executing begin transaction");
            Console.WriteLine("========================================================");
            r = BeginTransaction(dbPath);
            Console.WriteLine("Result: " + r.Result);
            Console.WriteLine("Message: " + r.Message);
            Console.WriteLine("txn-handle: " + r.TxnHandle);
            string txnHandle = r.TxnHandle;

            if (!r.Result)
            {
                Environment.Exit(1);
            }

            // Create a table
            Console.WriteLine("========================================================");
            Console.WriteLine("Executing create table");
            Console.WriteLine("========================================================");
            r = ExecuteSQL(dbPath, txnHandle, "create table if not exists t1(a int, b text)");
            Console.WriteLine("Result: " + r.Result);
            Console.WriteLine("Message: " + r.Message);

            if (!r.Result)
            {
                Environment.Exit(1);
            }

            // Insert data into table
            Console.WriteLine("========================================================");
            Console.WriteLine("Executing insert into table");
            Console.WriteLine("========================================================");
            JArray arguments = new JArray
            {
                new JArray { 1, "one" },
                new JArray { 2, "two" }
            };

            r = ExecuteSQL(dbPath, txnHandle, "insert into t1 (a, b) values (?, ?)", arguments);
            Console.WriteLine("Result: " + r.Result);
            Console.WriteLine("Message: " + r.Message);

            if (!r.Result)
            {
                Environment.Exit(1);
            }

            // Commit Transaction
            Console.WriteLine("========================================================");
            Console.WriteLine("Executing commit transaction");
            Console.WriteLine("========================================================");
            r = CommitTransaction(dbPath, txnHandle);
            Console.WriteLine("Result: " + r.Result);
            Console.WriteLine("Message: " + r.Message);

            if (!r.Result)
            {
                Environment.Exit(1);
            }

            // Select from table
            Console.WriteLine("========================================================");
            Console.WriteLine("Executing select from table");
            Console.WriteLine("========================================================");
            r = ExecuteSQL(dbPath, null, "select a, b from t1");
            Console.WriteLine("Result: " + r.Result);
            Console.WriteLine("Message: " + r.Message);

            Console.WriteLine("Selected Records: ");
            foreach (var rec in r.ResultSet)
            {
                Console.WriteLine($"a = {rec["a"]}, b = {rec["b"]}");
            }

            // Drop table
            Console.WriteLine("========================================================");
            Console.WriteLine("Executing drop table");
            Console.WriteLine("========================================================");
            r = ExecuteSQL(dbPath, null, "drop table t1");
            Console.WriteLine("Result: " + r.Result);
            Console.WriteLine("Message: " + r.Message);
        }

        private static void CreateDBDirs()
        {
            dbDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "synclite", "job1", "db");
            Directory.CreateDirectory(dbDir);
        }
    }
}
