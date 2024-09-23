import requests
import json
import os

"""
* ===========================================================
  Note: 
* ===========================================================
Install following dependencies

pip install requests


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
 
"""
class SyncLiteDBResult:
    def __init__(self, result, message, result_set=None, txn_handle=None):
        self.result = result
        self.message = message
        self.result_set = result_set
        self.txn_handle = txn_handle

# The base URL for the API
syncLiteDBAddress = "http://localhost:5555"

# Function to send an HTTP request
def process_request(json_request):
    response = None
    try:
        print(f"Request JSON: {json.dumps(json_request, indent=4)}")
        
        headers = {'Content-Type': 'application/json'}
        response = requests.post(syncLiteDBAddress, json=json_request, headers=headers, timeout=10)
        
        print(f"Response Code: {response.status_code}")
        
        if response.status_code == 200:
            json_response = response.json()
            print(f"Response JSON: {json.dumps(json_response, indent=4)}")
            
            result = json_response.get('result')
            message = json_response.get('message')
            print(f"Result: {result}")
            print(f"Message: {message}")
            
            return json_response
        else:
            raise Exception(f"Failed to get a valid response from the server : {response.status_code}")
    except Exception as e:
        raise Exception(f"Failed to process request: {str(e)}") from e

    return response

def initialize_db(db_path, db_type, db_name, logger_config_path=None):
    try:
        json_request = {
            "db-path": str(db_path),
            "db-type": db_type,
            "db-name": db_name,
            "sql": "initialize"
        }
        if logger_config_path:
            json_request["synclite-logger-config"] = str(logger_config_path)
        
        json_response = process_request(json_request)
        
        return SyncLiteDBResult(
            result=json_response.get('result'),
            message=json_response.get('message')
        )
    except Exception as e:
        raise Exception(f"Failed to initialize DB: {str(db_path)} : {str(e)}")

def close_db(db_path):
    try:
        json_request = {
            "db-path": str(db_path),
            "sql": "close"
        }

        json_response = process_request(json_request)
        
        return SyncLiteDBResult(
            result=json_response.get('result'),
            message=json_response.get('message')
        )
    except Exception as e:
        raise Exception(f"Failed to close DB: {str(db_path)} : {str(e)}")

def begin_transaction(db_path):
    try:
        json_request = {
            "db-path": str(db_path),
            "sql": "begin"
        }
        
        json_response = process_request(json_request)
        
        return SyncLiteDBResult(
            result=json_response.get('result'),
            message=json_response.get('message'),
			txn_handle=json_response.get('txn-handle')
        )
    except Exception as e:
        raise Exception(f"Failed to begin transaction on DB: {str(db_path)} : {str(e)}")

def commit_transaction(db_path, txn_handle):
    try:
        json_request = {
            "db-path": str(db_path),
            "sql": "commit",
			"txn-handle": txn_handle
        }
        
        json_response = process_request(json_request)
        
        return SyncLiteDBResult(
            result=json_response.get('result'),
            message=json_response.get('message')
        )
    except Exception as e:
        raise Exception(f"Failed to commit transaction on DB: {str(db_path)} : {str(e)}")

def rollback_transaction(db_path, txn_handle):
    try:
        json_request = {
            "db-path": str(db_path),
			"txn-handle": txn_handle,
            "sql": "rollback"
        }
        
        json_response = process_request(json_request)
        
        return SyncLiteDBResult(
            result=json_response.get('result'),
            message=json_response.get('message')
        )
    except Exception as e:
        raise Exception(f"Failed to rollback transaction on DB: {str(db_path)} : {str(e)}")

def execute_sql(db_path, txn_handle, sql, arguments):
    try:
        json_request = {
            "db-path": str(db_path),
            "sql": sql
        }

        if txn_handle:
            json_request["txn-handle"] = txn_handle

        if arguments:
            json_request["arguments"] = arguments
        
        json_response = process_request(json_request)
        
        return SyncLiteDBResult(
            result=json_response.get('result'),
            message=json_response.get('message'),			
		    result_set=json_response.get('resultset') if 'resultset' in json_response else None
        )
    except Exception as e:
        raise Exception(f"Failed to rollback transaction on DB: {str(db_path)} : {str(e)}")


# Init db directory
db_dir = os.path.join(os.path.expanduser("~"), "synclite", "job1", "db")
os.makedirs(db_dir, exist_ok=True)

db_path = os.path.join(db_dir, "testPython")

# Initialize DB
print("=" * 56)
print("Executing initialize DB")
print("=" * 56)
result = initialize_db(db_path, "SQLITE", "testPython", None)
print(f"Result: {result.result}, Message: {result.message}")
print("=" * 56)

# Start a transaction
print("=" * 56)
print("Executing begin transaction")
print("=" * 56)
r = begin_transaction(db_path)
print(f"result : {r.result}")
print(f"message : {r.message}")
print(f"txn-handle: {r.txn_handle}")
txn_handle = r.txn_handle
if not r.result:
    sys.exit(1)
print("=" * 56)


# Create a Table
print("=" * 56)
print("Executing create table")
print("=" * 56)
r = execute_sql(db_path, txn_handle, "create table if not exists t1(a int, b text)", None)
print(f"result : {r.result}")
print(f"message : {r.message}")
if not r.result:
    sys.exit(1)
print("=" * 56)

# Insert Data in a table
print("=" * 56)
print("Executing insert into table")
print("=" * 56)
arguments = [
    [1, "one"],
    [2, "two"]
]
r = execute_sql(db_path, txn_handle, "insert into t1 (a,b) values(?, ?)", arguments)
print(f"result : {r.result}")
print(f"message : {r.message}")
if not r.result:
    sys.exit(1)
print("=" * 56)


# Commit Transaction
print("=" * 56)
print("Executing commit transaction")
print("=" * 56)
r = commit_transaction(db_path, txn_handle)
print(f"result : {r.result}")
print(f"message : {r.message}")
if not r.result:
    sys.exit(1)
print("=" * 56)


# Select from table
print("=" * 56)
print("Executing select from table")
print("=" * 56)
r = execute_sql(db_path, None, "select a, b from t1", None)
print(f"result : {r.result}")
print(f"message : {r.message}")
result_set = r.result_set
print("Selected Records: ")
for rec in result_set:
    print(f"a = {rec['a']}, b = {rec['b']}")
print("=" * 56)


# Drop table
print("=" * 56)
print("Executing drop table")
print("=" * 56)
r = execute_sql(db_path, None, "drop table t1", None)
print(f"result : {r.result}")
print(f"message : {r.message}")


# Close DB
print("=" * 56)
print("Executing close DB")
print("=" * 56)
r = close_db(db_path)
print(f"result : {r.result}")
print(f"message : {r.message}")
print("=" * 56)
