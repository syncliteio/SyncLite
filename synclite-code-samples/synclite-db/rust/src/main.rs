use reqwest::blocking::Client;
use reqwest::header::CONTENT_TYPE;
use serde_json::{json, Value};
use std::time::{SystemTime, UNIX_EPOCH};
use std::collections::HashMap;

use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};

/*
* ===========================================================
  Note: 
* ===========================================================

Refer Cargo.toml file for dependencies.


This source file implements following APIs to connect to SyncLiteDB:

1. initializeDB : Initialize the given database/device of specified type (SQLITE, DUCKDB, DERBY, H2, HYPERSQL, SQLITE_APPENDER, DUCKDB_APPENDER, DERBY_APPENDER, H2_APPENDER, HYPERSQL_APPENDER, STREAMING) with the specified db-name.
2. beginTransaction: Begin a transaction on specified database, returning a transaction handle
3. executeSQL: Execute specified SQL with (optional arguments for batch operations with prepared statements), on the specified database.
4. commitTransction: Commit the transaction with given transaction handle
5. rollbackTransaction: Rollback the transaction with given transaction handle
6. closeDB: Close the given database.

Applications send db-name (not db-path). SyncLite DB resolves the physical database path internally.

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
    resultset_handle: Option<String>,
    has_more: Option<bool>,
    column_metadata: Option<Value>,
}

const SYNC_LITE_DB_ADDRESS: &str = "http://localhost:5555";

fn process_request(json_request: &Value) -> Result<Value, String> {
	
    println!("Request JSON: {}", json_request);

    let payload = serde_json::to_string(json_request).map_err(|e| e.to_string())?;
    let mut headers: HashMap<String, String> = HashMap::new();
    headers.insert("Content-Type".to_string(), "application/json".to_string());

    if let Ok(token) = std::env::var("SYNCLITE_DB_AUTH_TOKEN") {
        if !token.is_empty() {
            headers.insert("X-SyncLite-Token".to_string(), token);
        }
    }

    let app_id = std::env::var("SYNCLITE_DB_APP_ID").ok();
    let app_secret = std::env::var("SYNCLITE_DB_APP_SECRET").ok();
    if let (Some(app_id), Some(app_secret)) = (app_id, app_secret) {
        if !app_id.is_empty() && !app_secret.is_empty() {
            let timestamp = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map_err(|e| e.to_string())?
                .as_millis()
                .to_string();

            let nonce = format!("{:x}", rand::random::<u128>());
            let body_hash = format!("{:x}", Sha256::digest(payload.as_bytes()));
            let canonical = format!("POST\n/\n{}\n{}\n{}", timestamp, nonce, body_hash);

            let mut mac = Hmac::<Sha256>::new_from_slice(app_secret.as_bytes()).map_err(|e| e.to_string())?;
            mac.update(canonical.as_bytes());
            let signature = base64::encode(mac.finalize().into_bytes());

            headers.insert("X-SyncLite-App-Id".to_string(), app_id);
            headers.insert("X-SyncLite-Timestamp".to_string(), timestamp);
            headers.insert("X-SyncLite-Nonce".to_string(), nonce);
            headers.insert("X-SyncLite-Signature".to_string(), signature);
        }
    }

    let client = Client::new();
    let mut request = client
        .post(SYNC_LITE_DB_ADDRESS)
        .header(CONTENT_TYPE, "application/json");

    for (k, v) in headers {
        request = request.header(k, v);
    }

    let response = request
        .body(payload)
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

fn to_db_result(json_response: &Value) -> SyncLiteDBResult {
    SyncLiteDBResult {
        result: json_response["result"].as_bool().unwrap_or(false),
        message: json_response["message"].as_str().unwrap_or_default().to_string(),
        result_set: json_response.get("resultset").cloned(),
        txn_handle: json_response.get("txn-handle").and_then(Value::as_str).map(|s| s.to_string()),
        resultset_handle: json_response.get("resultset-handle").and_then(Value::as_str).map(|s| s.to_string()),
        has_more: json_response.get("has-more").and_then(Value::as_bool),
        column_metadata: json_response.get("resultset-metadata").cloned(),
    }
}

fn initialize_db(db_name: &str, db_type: &str, logger_options: Option<&Value>) -> Result<SyncLiteDBResult, String> {
    let mut json_request = json!({
        "db-type": db_type,
        "db-name": db_name,
        "sql": "initialize",
    });

    if let Some(opts) = logger_options {
        json_request["synclite-logger-options"] = opts.clone();
    }

    let json_response = process_request(&json_request)?;

    Ok(to_db_result(&json_response))
}

fn begin_transaction(db_name: &str) -> Result<SyncLiteDBResult, String> {
    let json_request = json!({
        "db-name": db_name,
        "sql": "begin",
    });

    let json_response = process_request(&json_request)?;

    Ok(to_db_result(&json_response))
}

fn commit_transaction(db_name: &str, txn_handle: &str) -> Result<SyncLiteDBResult, String> {
    let json_request = json!({
        "db-name": db_name,
        "txn-handle": txn_handle,
        "sql": "commit",
    });

    let json_response = process_request(&json_request)?;

    Ok(to_db_result(&json_response))
}

fn rollback_transaction(db_name: &str, txn_handle: &str) -> Result<SyncLiteDBResult, String> {
    let json_request = json!({
        "db-name": db_name,
        "txn-handle": txn_handle,
        "sql": "rollback",
    });

    let json_response = process_request(&json_request)?;

    Ok(to_db_result(&json_response))
}

fn execute_sql(db_name: &str, txn_handle: Option<&str>, sql: &str, arguments: Option<&Value>, data_format: Option<&str>, include_metadata: Option<bool>) -> Result<SyncLiteDBResult, String> {
    let mut json_request = json!({
        "db-name": db_name,
        "sql": sql,
    });

    if let Some(handle) = txn_handle {
        json_request["txn-handle"] = json!(handle);
    }
    if let Some(args) = arguments {
        json_request["arguments"] = args.clone();
    }
    if let Some(fmt) = data_format {
        json_request["resultset-data-format"] = json!(fmt);
    }
    if let Some(meta) = include_metadata {
        json_request["resultset-include-metadata"] = json!(if meta { "ON" } else { "OFF" });
    }

    let json_response = process_request(&json_request)?;

    Ok(to_db_result(&json_response))
}

fn next_page(resultset_handle: &str, resultset_pagination_size: Option<u64>, data_format: Option<&str>, include_metadata: Option<bool>) -> Result<SyncLiteDBResult, String> {
    let mut json_request = json!({
        "request-type": "next",
        "resultset-handle": resultset_handle,
    });

    if let Some(size) = resultset_pagination_size {
        if size > 0 {
            json_request["resultset-pagination-size"] = json!(size);
        }
    }
    if let Some(fmt) = data_format {
        json_request["resultset-data-format"] = json!(fmt);
    }
    if let Some(meta) = include_metadata {
        json_request["resultset-include-metadata"] = json!(if meta { "ON" } else { "OFF" });
    }

    let json_response = process_request(&json_request)?;
    Ok(to_db_result(&json_response))
}

fn close_db(db_name: &str) -> Result<SyncLiteDBResult, String> {
    let json_request = json!({
        "db-name": db_name,
        "sql": "close",
    });

    let json_response = process_request(&json_request)?;

    Ok(to_db_result(&json_response))
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let db_name = "testRust";

    println!("========================================================");
    println!("Executing initialize DB");
    println!("========================================================");
    let r = initialize_db(db_name, "SQLITE", None).map_err(|e| format!("Error: {}", e))?;
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
    let r = begin_transaction(db_name).map_err(|e| format!("Error: {}", e))?;
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
    let r = execute_sql(db_name, Some(txn_handle), "create table if not exists t1(a int, b text)", None, None, None).map_err(|e| format!("Error: {}", e))?;
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

    let r = execute_sql(db_name, Some(txn_handle), "insert into t1 (a, b) values(?, ?)", Some(&arguments), None, None).map_err(|e| format!("Error: {}", e))?;
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
    let r = commit_transaction(db_name, txn_handle).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);
    if !r.result {
        return Ok(());
    }
    println!("========================================================");

    // Select from table (JSON format - default, records as {colName: colValue} objects)
    println!("========================================================");
    println!("Executing select from table (JSON format)");
    println!("========================================================");
    let r = execute_sql(db_name, None, "select a, b from t1", None, None, None).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);

    if let Some(meta) = &r.column_metadata {
        if let Some(cols) = meta.as_array() {
            let headers: Vec<&str> = cols.iter().filter_map(|c| c["label"].as_str()).collect();
            println!("{}", headers.join("\t"));
        }
    }
    let mut current = r;
    loop {
        if let Some(result_set) = &current.result_set {
            if let Some(array) = result_set.as_array() {
                for record in array {
                    if let (Some(a), Some(b)) = (record.get("a"), record.get("b")) {
                        println!("a = {}, b = {}", a, b);
                    }
                }
            }
        }

        let has_more = current.has_more.unwrap_or(false);
        let handle = current.resultset_handle.clone();
        if !has_more || handle.is_none() {
            break;
        }

        let next_handle = handle.unwrap();
        current = next_page(&next_handle, None, None, None).map_err(|e| format!("Error: {}", e))?;
        if !current.result {
            return Err(format!("Next page call failed: {}", current.message).into());
        }
    }
    println!("========================================================");

    // Select from table (DB format - records as value arrays, column order matches column_metadata)
    println!("========================================================");
    println!("Executing select from table (DB format)");
    println!("========================================================");
    let r = execute_sql(db_name, None, "select a, b from t1", None, Some("DB"), Some(true)).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);

    if let Some(meta) = &r.column_metadata {
        if let Some(cols) = meta.as_array() {
            let headers: Vec<&str> = cols.iter().filter_map(|c| c["label"].as_str()).collect();
            println!("{}", headers.join("\t"));
        }
    }
    let mut current = r;
    loop {
        if let Some(result_set) = &current.result_set {
            if let Some(array) = result_set.as_array() {
                for row in array {
                    if let Some(values) = row.as_array() {
                        let vals: Vec<String> = values.iter().map(|v| {
                            if v.is_null() { "null".to_string() } else { v.to_string() }
                        }).collect();
                        println!("{}", vals.join("\t"));
                    }
                }
            }
        }

        let has_more = current.has_more.unwrap_or(false);
        let handle = current.resultset_handle.clone();
        if !has_more || handle.is_none() {
            break;
        }

        let next_handle = handle.unwrap();
        current = next_page(&next_handle, None, Some("DB"), None).map_err(|e| format!("Error: {}", e))?;
        if !current.result {
            return Err(format!("Next page call failed: {}", current.message).into());
        }
    }

    // Drop table
    println!("========================================================");
    println!("Executing drop table");
    println!("========================================================");
    let r = execute_sql(db_name, None, "drop table t1", None, None, None).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);

    // Close DB
    println!("========================================================");
    println!("Executing close DB");
    println!("========================================================");
    let r = close_db(db_name).map_err(|e| format!("Error: {}", e))?;
    println!("result : {}", r.result);
    println!("message : {}", r.message);
    println!("========================================================");

    Ok(())
}
