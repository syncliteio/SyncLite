using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Security.Cryptography;
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
        public string ResultsetHandle { get; set; }
        public bool? HasMore { get; set; }
        public JArray ColumnMetadata { get; set; }
    }

    public class SyncLiteDBClient
    {
        private static string syncLiteDBAddress = "http://localhost:5555";
        private static string dbDir;

        private static SyncLiteDBResult ToDBResult(JObject jsonResponse)
        {
            return new SyncLiteDBResult
            {
                Result = jsonResponse["result"] != null && jsonResponse["result"].ToObject<bool>(),
                Message = jsonResponse["message"]?.ToString(),
                ResultSet = jsonResponse["resultset"] as JArray,
                TxnHandle = jsonResponse["txn-handle"]?.ToString(),
                ResultsetHandle = jsonResponse["resultset-handle"]?.ToString(),
                HasMore = jsonResponse["has-more"]?.ToObject<bool>(),
                ColumnMetadata = jsonResponse["resultset-metadata"] as JArray
            };
        }

        private static string Sha256Hex(string value)
        {
            using (var sha = SHA256.Create())
            {
                byte[] hash = sha.ComputeHash(Encoding.UTF8.GetBytes(value));
                StringBuilder sb = new StringBuilder();
                foreach (byte b in hash)
                {
                    sb.Append(b.ToString("x2"));
                }
                return sb.ToString();
            }
        }

        public static JObject ProcessRequest(JObject jsonRequest)
        {
            JObject jsonResponse = null;

            try
            {
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(syncLiteDBAddress);
                request.Method = "POST";
                request.ContentType = "application/json";
                request.Timeout = 10000;

                string payload = jsonRequest.ToString(Formatting.None);
                string token = Environment.GetEnvironmentVariable("SYNCLITE_DB_AUTH_TOKEN");
                if (!string.IsNullOrEmpty(token))
                {
                    request.Headers["X-SyncLite-Token"] = token;
                }

                string appId = Environment.GetEnvironmentVariable("SYNCLITE_DB_APP_ID");
                string appSecret = Environment.GetEnvironmentVariable("SYNCLITE_DB_APP_SECRET");
                if (!string.IsNullOrEmpty(appId) && !string.IsNullOrEmpty(appSecret))
                {
                    string timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString();
                    string nonce = Guid.NewGuid().ToString();
                    string canonical = "POST\n/\n" + timestamp + "\n" + nonce + "\n" + Sha256Hex(payload);
                    using (var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(appSecret)))
                    {
                        string signature = Convert.ToBase64String(hmac.ComputeHash(Encoding.UTF8.GetBytes(canonical)));
                        request.Headers["X-SyncLite-App-Id"] = appId;
                        request.Headers["X-SyncLite-Timestamp"] = timestamp;
                        request.Headers["X-SyncLite-Nonce"] = nonce;
                        request.Headers["X-SyncLite-Signature"] = signature;
                    }
                }

                Console.WriteLine("Request JSON: " + jsonRequest.ToString(Formatting.Indented));

                // Send the JSON request
                using (var streamWriter = new StreamWriter(request.GetRequestStream()))
                {
                    streamWriter.Write(payload);
                    streamWriter.Flush();
                    streamWriter.Close();
                }

                // Get the response
                HttpWebResponse response;
                try
                {
                    response = (HttpWebResponse)request.GetResponse();
                }
                catch (WebException ex)
                {
                    response = ex.Response as HttpWebResponse;
                    if (response == null)
                    {
                        throw;
                    }
                }

                using (response)
                {
                    using (var streamReader = new StreamReader(response.GetResponseStream()))
                    {
                        string result = streamReader.ReadToEnd();
                        jsonResponse = JObject.Parse(result);
                    }

                    if (response.StatusCode != HttpStatusCode.OK && response.StatusCode != HttpStatusCode.BadRequest && response.StatusCode != HttpStatusCode.Unauthorized && (int)response.StatusCode != 413)
                    {
                        throw new Exception("Failed to get a valid response from the server : " + response.StatusCode);
                    }

                    Console.WriteLine("Response JSON: " + jsonResponse.ToString(Formatting.Indented));
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

                return ToDBResult(jsonResponse);
            }
            catch (Exception e)
            {
                throw new Exception("Failed to initialize DB: " + dbPath + " : " + e.Message, e);
            }
        }

        public static SyncLiteDBResult BeginTransaction(string dbPath)
        {
            try
            {
                JObject jsonRequest = new JObject
                {
                    { "db-path", dbPath },
                    { "sql", "begin" }
                };

                JObject jsonResponse = ProcessRequest(jsonRequest);

                return ToDBResult(jsonResponse);
            }
            catch (Exception e)
            {
                throw new Exception("Failed to begin transaction on DB: " + dbPath + " : " + e.Message, e);
            }
        }

        public static SyncLiteDBResult CommitTransaction(string dbPath, string txnHandle)
        {
            try
            {
                JObject jsonRequest = new JObject
                {
                    { "db-path", dbPath },
                    { "txn-handle", txnHandle },
                    { "sql", "commit" }
                };

                JObject jsonResponse = ProcessRequest(jsonRequest);

                return ToDBResult(jsonResponse);
            }
            catch (Exception e)
            {
                throw new Exception("Failed to commit transaction on DB: " + dbPath + " : " + e.Message, e);
            }
        }

	public static SyncLiteDBResult RollbackTransaction(string dbPath, string txnHandle)
        {
            try
            {
                JObject jsonRequest = new JObject
                {
                    { "db-path", dbPath },
                    { "txn-handle", txnHandle },
                    { "sql", "rollback" }
                };

                JObject jsonResponse = ProcessRequest(jsonRequest);

                return ToDBResult(jsonResponse);
            }
            catch (Exception e)
            {
                throw new Exception("Failed to commit transaction on DB: " + dbPath + " : " + e.Message, e);
            }
        }


        public static SyncLiteDBResult ExecuteSQL(string dbPath, string txnHandle, string sql, JArray arguments = null, string dataFormat = null, bool? includeMetadata = null)
        {
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

                if (dataFormat != null)
                {
                    jsonRequest["resultset-data-format"] = dataFormat;
                }

                if (includeMetadata.HasValue)
                {
                    jsonRequest["resultset-include-metadata"] = includeMetadata.Value ? "ON" : "OFF";
                }

                JObject jsonResponse = ProcessRequest(jsonRequest);

                return ToDBResult(jsonResponse);
            }
            catch (Exception e)
            {
                throw new Exception("Failed to execute SQL on DB: " + dbPath + " : " + e.Message, e);
            }
        }

        public static SyncLiteDBResult Next(string resultsetHandle, int? resultsetPaginationSize = null, string dataFormat = null, bool? includeMetadata = null)
        {
            try
            {
                JObject jsonRequest = new JObject
                {
                    { "request-type", "next" },
                    { "resultset-handle", resultsetHandle }
                };

                if (resultsetPaginationSize.HasValue && resultsetPaginationSize.Value > 0)
                {
                    jsonRequest["resultset-pagination-size"] = resultsetPaginationSize.Value;
                }

                if (dataFormat != null)
                {
                    jsonRequest["resultset-data-format"] = dataFormat;
                }

                if (includeMetadata.HasValue)
                {
                    jsonRequest["resultset-include-metadata"] = includeMetadata.Value ? "ON" : "OFF";
                }

                JObject jsonResponse = ProcessRequest(jsonRequest);
                return ToDBResult(jsonResponse);
            }
            catch (Exception e)
            {
                throw new Exception("Failed to fetch next page for resultset-handle: " + resultsetHandle + " : " + e.Message, e);
            }
        }

        public static SyncLiteDBResult CloseDB(string dbPath)
        {
            try
            {
                JObject jsonRequest = new JObject
                {
                    { "db-path", dbPath },
                    { "sql", "close" }
                };

                JObject jsonResponse = ProcessRequest(jsonRequest);
                return ToDBResult(jsonResponse);
            }
            catch (Exception e)
            {
                throw new Exception("Failed to close DB: " + dbPath + " : " + e.Message, e);
            }
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

            // Select from table (JSON format - default, records as {colName: colValue} objects)
            Console.WriteLine("========================================================");
            Console.WriteLine("Executing select from table (JSON format)");
            Console.WriteLine("========================================================");
            r = ExecuteSQL(dbPath, null, "select a, b from t1");
            Console.WriteLine("Result: " + r.Result);
            Console.WriteLine("Message: " + r.Message);

            if (r.ColumnMetadata != null)
            {
                Console.WriteLine(string.Join("\t", r.ColumnMetadata.Select(c => c["label"]?.ToString())));
            }
            SyncLiteDBResult current = r;
            while (true)
            {
                if (current.ResultSet != null)
                {
                    foreach (var rec in current.ResultSet)
                    {
                        Console.WriteLine($"a = {rec["a"]}, b = {rec["b"]}");
                    }
                }

                if (current.HasMore != true || string.IsNullOrEmpty(current.ResultsetHandle))
                {
                    break;
                }

                current = Next(current.ResultsetHandle);
                if (!current.Result)
                {
                    throw new Exception("Next page call failed: " + current.Message);
                }
            }

            // Select from table (DB format - records as value arrays, column order matches ColumnMetadata)
            Console.WriteLine("========================================================");
            Console.WriteLine("Executing select from table (DB format)");
            Console.WriteLine("========================================================");
            r = ExecuteSQL(dbPath, null, "select a, b from t1", null, "DB", true);
            Console.WriteLine("Result: " + r.Result);
            Console.WriteLine("Message: " + r.Message);

            if (r.ColumnMetadata != null)
            {
                Console.WriteLine(string.Join("\t", r.ColumnMetadata.Select(c => c["label"]?.ToString())));
            }
            current = r;
            while (true)
            {
                if (current.ResultSet != null)
                {
                    foreach (var row in current.ResultSet)
                    {
                        var rowArr = row as JArray;
                        if (rowArr != null)
                        {
                            Console.WriteLine(string.Join("\t", rowArr.Select(v => v.Type == JTokenType.Null ? "null" : v.ToString())));
                        }
                    }
                }

                if (current.HasMore != true || string.IsNullOrEmpty(current.ResultsetHandle))
                {
                    break;
                }

                current = Next(current.ResultsetHandle, null, "DB");
                if (!current.Result)
                {
                    throw new Exception("Next page call failed: " + current.Message);
                }
            }

            // Drop table
            Console.WriteLine("========================================================");
            Console.WriteLine("Executing drop table");
            Console.WriteLine("========================================================");
            r = ExecuteSQL(dbPath, null, "drop table t1");
            Console.WriteLine("Result: " + r.Result);
            Console.WriteLine("Message: " + r.Message);

            Console.WriteLine("========================================================");
            Console.WriteLine("Executing close DB");
            Console.WriteLine("========================================================");
            r = CloseDB(dbPath);
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
