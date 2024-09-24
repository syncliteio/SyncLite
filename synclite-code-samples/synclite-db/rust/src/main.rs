use reqwest::blocking::Client;
use reqwest::header::CONTENT_TYPE;
use serde_json::{json, Value};
use std::fs;
use std::path::{Path, PathBuf};

/*
* ===========================================================
  Note: 
* ===========================================================

Refer Cargo.toml file for dependencies.


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

#[derive(Debug)]
struct SyncLiteDBResult {
    result: bool,
    message: String,
    result_set: Option<Value>,
    txn_handle: Option<String>,
}

const SYNC_LITE_DB_ADDRESS: &str = "http://localhost:5555";
static mut DB_DIR: Option<PathBuf> = None;

fn process_request(json_request: &Value) -> Result<Value, String> {
	
    println!("Request JSON: {}", json_request);

    let client = Client::new();
    let response = client
        .post(SYNC_LITE_DB_ADDRESS)
        .header(CONTENT_TYPE, "application/json")
        .json(json_request)
        .send()
        .map_err(|e| e.to_string())?;

    if response.status().is_success() {
        let json_response: Value = response.json().map_err(|e| e.to_string())?;
        println!("Response JSON: {}", json_response);
        Ok(json_response)
    } else {
        let error_message = response.text().unwrap_or_else(|_| "Unknown error".to_string());
        Err(error_message)
    }
}

fn initialize_db(db_path: &Path, db_type: &str, db_name: &str) -> Result<SyncLiteDBResult, String> {
    let json_request = json!({
        "db-path": db_path.to_str().unwrap(),
        "db-type": db_type,
        "db-name": db_name,
        "sql": "initialize",
    });

    let json_response = process_request(&json_request)?;

    Ok(SyncLiteDBResult {
        result: json_response["result"].as_bool().unwrap(),
        message: json_response["message"].as_str().unwrap().to_string(),
        result_set: None,
        txn_handle: None,
    })
}

fn begin_transaction(db_path: &Path) -> Result<SyncLiteDBResult, String> {
    let json_request = json!({
        "db-path": db_path.to_str().unwrap(),
        "sql": "begin",
    });

    let json_response = process_request(&json_request)?;

    Ok(SyncLiteDBResult {
        result: json_response["result"].as_bool().unwrap(),
        message: json_response["message"].as_str().unwrap().to_string(),
        txn_handle: json_response.get("txn-handle").and_then(Value::as_str).map(|s| s.to_string()),
        result_set: None,
    })
}

fn commit_transaction(db_path: &Path, txn_handle: &str) -> Result<SyncLiteDBResult, String> {
    let json_request = json!({
        "db-path": db_path.to_str().unwrap(),
        "txn-handle": txn_handle,
        "sql": "commit",
    });

    let json_response = process_request(&json_request)?;

    Ok(SyncLiteDBResult {
        result: json_response["result"].as_bool().unwrap(),
        message: json_response["message"].as_str().unwrap().to_string(),
        result_set: None,
        txn_handle: None,
    })
}

fn execute_sql(db_path: &Path, txn_handle: Option<&str>, sql: &str, arguments: Option<&Value>) -> Result<SyncLiteDBResult, String> {
    let mut json_request = json!({
        "db-path": db_path.to_str().unwrap(),
        "sql": sql,
    });

    if let Some(handle) = txn_handle {
        json_request["txn-handle"] = json!(handle);
    }
    if let Some(args) = arguments {
        json_request["arguments"] = args.clone();
    }

    let json_response = process_request(&json_request)?;

    Ok(SyncLiteDBResult {
        result: json_response["result"].as_bool().unwrap(),
        message: json_response["message"].as_str().unwrap().to_string(),
        result_set: json_response.get("resultset").cloned(),
        txn_handle: None,
    })
}

fn close_db(db_path: &Path) -> Result<SyncLiteDBResult, String> {
    let json_request = json!({
        "db-path": db_path.to_str().unwrap(),
        "sql": "close",
    });

    let json_response = process_request(&json_request)?;

    Ok(SyncLiteDBResult {
        result: json_response["result"].as_bool().unwrap(),
        message: json_response["message"].as_str().unwrap().to_string(),
        result_set: None,
        txn_handle: None,
    })
}

fn create_db_dirs() -> std::io::Result<()> {
    let home_dir = std::env::var("USERPROFILE").expect("USERPROFILE environment variable not set");

    let db_path_str = format!("{}/synclite/job1/db", home_dir);
    let db_dir = Path::new(&db_path_str);
    fs::create_dir_all(&db_dir)?;
    unsafe { DB_DIR = Some(db_dir.to_path_buf()) };
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    create_db_dirs()?;

    let db_path = unsafe { DB_DIR.as_ref().unwrap().join("testRust.db") };

    println!("========================================================");
    println!("Executing initialize DB");
    println!("========================================================");
    let r = initialize_db(&db_path, "SQLITE", "testRust").map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);
    if !r.result {
        return Ok(());
    }
    println!("========================================================");

    // Start a transaction
    println!("========================================================");
    println!("Executing begin transaction");
    println!("========================================================");
    let r = begin_transaction(&db_path).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);
    let txn_handle = r.txn_handle.as_ref().unwrap();
    if !r.result {
        return Ok(());
    }
    println!("========================================================");

    // Create a Table
    println!("========================================================");
    println!("Executing create table");
    println!("========================================================");
    let r = execute_sql(&db_path, Some(txn_handle), "create table if not exists t1(a int, b text)", None).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);
    if !r.result {
        return Ok(());
    }
    println!("========================================================");

    // Insert Data into a table
    println!("========================================================");
    println!("Executing insert into table");
    println!("========================================================");
    let arguments = json!([
        [1, "one"],
        [2, "two"],
    ]);

    let r = execute_sql(&db_path, Some(txn_handle), "insert into t1 (a, b) values(?, ?)", Some(&arguments)).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);
    if !r.result {
        return Ok(());
    }
    println!("========================================================");

    // Commit Transaction
    println!("========================================================");
    println!("Executing commit transaction");
    println!("========================================================");
    let r = commit_transaction(&db_path, txn_handle).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);
    if !r.result {
        return Ok(());
    }
    println!("========================================================");

    // Select from table
    println!("========================================================");
    println!("Executing select from table");
    println!("========================================================");
    let r = execute_sql(&db_path, None, "select a, b from t1", None).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);

	if let Some(result_set) = r.result_set {
		if let Some(array) = result_set.as_array() {
			println!("Selected Records:");
			for record in array {
				if let (Some(a), Some(b)) = (record.get("a"), record.get("b")) {
					println!("a = {}, b = {}", a, b);
				}
			}
		} else {
			println!("No records found.");
		}
	} else {
		println!("Result set is not available.");
	}
    println!("========================================================");

    // Drop table
    println!("========================================================");
    println!("Executing drop table");
    println!("========================================================");
    let r = execute_sql(&db_path, None, "drop table t1", None).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);

    // Close DB
    println!("========================================================");
    println!("Executing close DB");
    println!("========================================================");
    let r = close_db(&db_path).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);
    println!("========================================================");

    Ok(())
}
