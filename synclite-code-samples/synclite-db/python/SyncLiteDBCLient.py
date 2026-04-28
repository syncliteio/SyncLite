import requests
import json
import os
import sys
import time
import uuid
import base64
import hashlib
import hmac

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
    def __init__(self, result, message, result_set=None, txn_handle=None, resultset_handle=None, has_more=None, column_metadata=None):
        self.result = result
        self.message = message
        self.result_set = result_set
        self.txn_handle = txn_handle
        self.resultset_handle = resultset_handle
        self.has_more = has_more
        self.column_metadata = column_metadata


def _to_result(json_response):
    return SyncLiteDBResult(
        result=json_response.get('result'),
        message=json_response.get('message'),
        result_set=json_response.get('resultset') if 'resultset' in json_response else None,
        txn_handle=json_response.get('txn-handle') if 'txn-handle' in json_response else None,
        resultset_handle=json_response.get('resultset-handle') if 'resultset-handle' in json_response else None,
        has_more=json_response.get('has-more') if 'has-more' in json_response else None,
        column_metadata=json_response.get('resultset-metadata') if 'resultset-metadata' in json_response else None
    )

# The base URL for the API
syncLiteDBAddress = "http://localhost:5555"

def _sha256_hex(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()

def _build_auth_headers(payload):
    headers = {'Content-Type': 'application/json'}

    token = os.getenv("SYNCLITE_DB_AUTH_TOKEN")
    if token:
        headers['X-SyncLite-Token'] = token

    app_id = os.getenv("SYNCLITE_DB_APP_ID")
    app_secret = os.getenv("SYNCLITE_DB_APP_SECRET")
    if app_id and app_secret:
        timestamp = str(int(time.time() * 1000))
        nonce = str(uuid.uuid4())
        canonical = "POST\n/\n" + timestamp + "\n" + nonce + "\n" + _sha256_hex(payload)
        signature = base64.b64encode(
            hmac.new(app_secret.encode("utf-8"), canonical.encode("utf-8"), hashlib.sha256).digest()
        ).decode("utf-8")

        headers['X-SyncLite-App-Id'] = app_id
        headers['X-SyncLite-Timestamp'] = timestamp
        headers['X-SyncLite-Nonce'] = nonce
        headers['X-SyncLite-Signature'] = signature

    return headers

# Function to send an HTTP request
def process_request(json_request):
    try:
        print(f"Request JSON: {json.dumps(json_request, indent=4)}")

        payload = json.dumps(json_request, separators=(",", ":"), ensure_ascii=False)
        headers = _build_auth_headers(payload)
        response = requests.post(syncLiteDBAddress, data=payload.encode("utf-8"), headers=headers, timeout=10)
        
        print(f"Response Code: {response.status_code}")
        
        if response.status_code in (200, 400, 401, 413):
            json_response = response.json()
            print(f"Response JSON: {json.dumps(json_response, indent=4)}")
            
            result = json_response.get('result')
            message = json_response.get('message')
            print(f"Result: {result}")
            print(f"Message: {message}")
            
            return json_response
        raise Exception(f"Failed to get a valid response from the server : {response.status_code} : {response.text}")
    except Exception as e:
        raise Exception(f"Failed to process request: {str(e)}") from e

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
        
        return _to_result(json_response)
    except Exception as e:
        raise Exception(f"Failed to initialize DB: {str(db_path)} : {str(e)}")

def close_db(db_path):
    try:
        json_request = {
            "db-path": str(db_path),
            "sql": "close"
        }

        json_response = process_request(json_request)
        
        return _to_result(json_response)
    except Exception as e:
        raise Exception(f"Failed to close DB: {str(db_path)} : {str(e)}")

def begin_transaction(db_path):
    try:
        json_request = {
            "db-path": str(db_path),
            "sql": "begin"
        }
        
        json_response = process_request(json_request)
        
        return _to_result(json_response)
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
        
        return _to_result(json_response)
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
        
        return _to_result(json_response)
    except Exception as e:
        raise Exception(f"Failed to rollback transaction on DB: {str(db_path)} : {str(e)}")

def execute_sql(db_path, txn_handle, sql, arguments, data_format=None, include_metadata=None):
    try:
        json_request = {
            "db-path": str(db_path),
            "sql": sql
        }

        if txn_handle:
            json_request["txn-handle"] = txn_handle

        if arguments:
            json_request["arguments"] = arguments

        if data_format is not None:
            json_request["resultset-data-format"] = data_format

        if include_metadata is not None:
            json_request["resultset-include-metadata"] = "ON" if include_metadata else "OFF"
        
        json_response = process_request(json_request)
        
        return _to_result(json_response)
    except Exception as e:
        raise Exception(f"Failed to rollback transaction on DB: {str(db_path)} : {str(e)}")


def next_page(resultset_handle, resultset_pagination_size=None, data_format=None, include_metadata=None):
    try:
        json_request = {
            "request-type": "next",
            "resultset-handle": resultset_handle
        }
        if resultset_pagination_size and resultset_pagination_size > 0:
            json_request["resultset-pagination-size"] = resultset_pagination_size
        if data_format is not None:
            json_request["resultset-data-format"] = data_format
        if include_metadata is not None:
            json_request["resultset-include-metadata"] = "ON" if include_metadata else "OFF"

        json_response = process_request(json_request)
        return _to_result(json_response)
    except Exception as e:
        raise Exception(f"Failed to fetch next page for resultset-handle: {resultset_handle} : {str(e)}")


# Init db directory
db_dir = os.path.join(os.path.expanduser("~"), "synclite", "job1", "db")
os.makedirs(db_dir, exist_ok=True)

db_path = os.path.join(db_dir, "testPython.db")

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


# Select from table (JSON format - default, records as {colName: colValue} dicts)
print("=" * 56)
print("Executing select from table (JSON format)")
print("=" * 56)
r = execute_sql(db_path, None, "select a, b from t1", None)
print(f"result : {r.result}")
print(f"message : {r.message}")
if r.column_metadata:
    print("\t".join(col['label'] for col in r.column_metadata))
current = r
while True:
    if current.result_set:
        for rec in current.result_set:
            print(f"a = {rec['a']}, b = {rec['b']}")
    if not current.has_more or not current.resultset_handle:
        break
    current = next_page(current.resultset_handle)
    if not current.result:
        print(f"next failed: {current.message}")
        sys.exit(1)
print("=" * 56)


# Select from table (DB format - records as value arrays, column order matches metadata)
print("=" * 56)
print("Executing select from table (DB format)")
print("=" * 56)
r = execute_sql(db_path, None, "select a, b from t1", None, data_format="DB", include_metadata=True)
print(f"result : {r.result}")
print(f"message : {r.message}")
if r.column_metadata:
    print("\t".join(col['label'] for col in r.column_metadata))
current = r
while True:
    if current.result_set:
        for row in current.result_set:
            print("\t".join(str(v) if v is not None else "null" for v in row))
    if not current.has_more or not current.resultset_handle:
        break
    current = next_page(current.resultset_handle, data_format="DB")
    if not current.result:
        print(f"next failed: {current.message}")
        sys.exit(1)
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
