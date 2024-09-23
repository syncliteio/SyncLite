package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
)

/*
* ===========================================================
  Note: 
* ===========================================================

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


// SyncLiteDBResult holds the result from the SyncLite DB API
type SyncLiteDBResult struct {
    Result    bool                   `json:"result"`
    Message   string                 `json:"message"`
    ResultSet []map[string]interface{} `json:"resultset,omitempty"` // Slice of maps for each record
    TxnHandle string                `json:"txn-handle,omitempty"`  // Pointer to allow checking for presence
}

// SyncLiteDBAddress is the base URL for the API
var syncLiteDBAddress = "http://localhost:5555"

// processRequest sends an HTTP request to the SyncLiteDB API
func processRequest(jsonRequest map[string]interface{}) (SyncLiteDBResult, error) {
	var result SyncLiteDBResult
	requestBody, err := json.MarshalIndent(jsonRequest, "", "  ")
	if err != nil {
		return result, fmt.Errorf("failed to marshal JSON request: %v", err)
	}

	fmt.Println("Request JSON:", string(requestBody))

	req, err := http.NewRequest("POST", syncLiteDBAddress, bytes.NewBuffer(requestBody))
	if err != nil {
		return result, fmt.Errorf("failed to create request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return result, fmt.Errorf("failed to send request: %v", err)
	}
	defer resp.Body.Close()

	fmt.Println("Response Code:", resp.StatusCode)

	if resp.StatusCode == 200 {
		body, _ := ioutil.ReadAll(resp.Body)
		fmt.Println("Response JSON:", string(body))
		err = json.Unmarshal(body, &result)
		if err != nil {
			return result, fmt.Errorf("failed to parse JSON response: %v", err)
		}
	} else {
		return result, fmt.Errorf("failed to get a valid response from the server: %v", resp.StatusCode)
	}

	return result, nil
}

// initializeDB initializes the SyncLite database
func initializeDB(dbPath, dbType, dbName, loggerConfigPath string) (SyncLiteDBResult, error) {
	jsonRequest := map[string]interface{}{
		"db-path": dbPath,
		"db-type": dbType,
		"db-name": dbName,
		"sql":     "initialize",
	}

	if loggerConfigPath != "" {
		jsonRequest["synclite-logger-config"] = loggerConfigPath
	}

	return processRequest(jsonRequest)
}

// closeDB closes the SyncLite database
func closeDB(dbPath string) (SyncLiteDBResult, error) {
	jsonRequest := map[string]interface{}{
		"db-path": dbPath,
		"sql":     "close",
	}
	return processRequest(jsonRequest)
}

// beginTransaction starts a new transaction
func beginTransaction(dbPath string) (SyncLiteDBResult, error) {
	jsonRequest := map[string]interface{}{
		"db-path": dbPath,
		"sql":     "begin",
	}
	return processRequest(jsonRequest)
}

// commitTransaction commits the current transaction
func commitTransaction(dbPath, txnHandle string) (SyncLiteDBResult, error) {
	jsonRequest := map[string]interface{}{
		"db-path":    dbPath,
		"txn-handle": txnHandle,
		"sql":        "commit",
	}

	return processRequest(jsonRequest)
}

// rollbackTransaction rolls back the current transaction
func rollbackTransaction(dbPath, txnHandle string) (SyncLiteDBResult, error) {
	jsonRequest := map[string]interface{}{
		"db-path":    dbPath,
		"txn-handle": txnHandle,
		"sql":        "rollback",
	}
	return processRequest(jsonRequest)
}

// executeSQL executes an SQL statement on the database
func executeSQL(dbPath, txnHandle, sql string, arguments [][]interface{}) (SyncLiteDBResult, error) {
	jsonRequest := map[string]interface{}{
		"db-path": dbPath,
		"sql":     sql,
	}
	if txnHandle != "" {
		jsonRequest["txn-handle"] = txnHandle
	}
	if arguments != nil {
		jsonRequest["arguments"] = arguments
	}

	return processRequest(jsonRequest)
}

func main() {
	// Get the DB directory
	homeDir, _ := os.UserHomeDir()
	dbDir := filepath.Join(homeDir, "synclite", "job1", "db")
	err := os.MkdirAll(dbDir, os.ModePerm)
	if err != nil {
		log.Fatalf("Failed to create directory: %v", err)
	}

	dbPath := filepath.Join(dbDir, "testGo")

	// Initialize DB
	fmt.Println("========================================================")
	fmt.Println("Executing initialize DB")
	fmt.Println("========================================================")
	result, err := initializeDB(dbPath, "SQLITE", "testGo", "")
	if err != nil {
		log.Fatalf("Failed to initialize DB: %v", err)
	}
	fmt.Printf("Result: %v, Message: %v\n", result.Result, result.Message)
	fmt.Println("========================================================")

	// Begin a transaction
	fmt.Println("========================================================")
	fmt.Println("Executing begin transaction")
	fmt.Println("========================================================")
	r, err := beginTransaction(dbPath)
	if err != nil {
		log.Fatalf("Failed to begin transaction: %v", err)
	}
	fmt.Printf("result: %v, message: %v, txn-handle: %v\n", r.Result, r.Message, r.TxnHandle)
	txnHandle := r.TxnHandle
	if !r.Result {
		os.Exit(1)
	}
	fmt.Println("========================================================")

	// Create a Table
	fmt.Println("========================================================")
	fmt.Println("Executing create table")
	fmt.Println("========================================================")
	r, err = executeSQL(dbPath, txnHandle, "create table if not exists t1(a int, b text)", nil)
	if err != nil {
		log.Fatalf("Failed to create table: %v", err)
	}
	fmt.Printf("result: %v, message: %v\n", r.Result, r.Message)
	if !r.Result {
		os.Exit(1)
	}
	fmt.Println("========================================================")

	// Insert Data in a table
	fmt.Println("========================================================")
	fmt.Println("Executing insert into table")
	fmt.Println("========================================================")
	arguments := [][]interface{}{
		{1, "one"},
		{2, "two"},
	}
	r, err = executeSQL(dbPath, txnHandle, "insert into t1 (a,b) values(?, ?)", arguments)
	if err != nil {
		log.Fatalf("Failed to insert into table: %v", err)
	}
	fmt.Printf("result: %v, message: %v\n", r.Result, r.Message)
	if !r.Result {
		os.Exit(1)
	}
	fmt.Println("========================================================")

	// Commit Transaction
	fmt.Println("========================================================")
	fmt.Println("Executing commit transaction")
	fmt.Println("========================================================")
	r, err = commitTransaction(dbPath, txnHandle)
	if err != nil {
		log.Fatalf("Failed to commit transaction: %v", err)
	}
	fmt.Printf("result: %v, message: %v\n", r.Result, r.Message)
	if !r.Result {
		os.Exit(1)
	}
	fmt.Println("========================================================")

	// Select from table
	fmt.Println("========================================================")
	fmt.Println("Executing select from table")
	fmt.Println("========================================================")
	r, err = executeSQL(dbPath, "", "select a, b from t1", nil)
	if err != nil {
		log.Fatalf("Failed to select from table: %v", err)
	}
	fmt.Printf("result: %v, message: %v\n", r.Result, r.Message)
	fmt.Println("Selected Records:")
	for _, rec := range r.ResultSet {
		fmt.Printf("a = %v, b = %v\n", rec["a"], rec["b"])
	}
	fmt.Println("========================================================")

	// Drop table
	fmt.Println("========================================================")
	fmt.Println("Executing drop table")
	fmt.Println("========================================================")
	r, err = executeSQL(dbPath, "", "drop table t1", nil)
	if err != nil {
		log.Fatalf("Failed to drop table: %v", err)
	}
	fmt.Printf("result: %v, message: %v\n", r.Result, r.Message)
	fmt.Println("========================================================")

	// Close DB
	fmt.Println("========================================================")
	fmt.Println("Executing close DB")
	fmt.Println("========================================================")
	r, err = closeDB(dbPath)
	if err != nil {
		log.Fatalf("Failed to close DB: %v", err)
	}
	fmt.Printf("result: %v, message: %v\n", r.Result, r.Message)
	fmt.Println("========================================================")
}
