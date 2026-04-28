package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
    "time"
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
	Result          bool                       `json:"result"`
	Message         string                     `json:"message"`
	ResultSet       []map[string]interface{}   `json:"resultset,omitempty"`
	TxnHandle       string                     `json:"txn-handle,omitempty"`
	ResultsetHandle string                     `json:"resultset-handle,omitempty"`
	HasMore         bool                       `json:"has-more,omitempty"`
	ColumnMetadata  []map[string]interface{}   `json:"resultset-metadata,omitempty"`
}

// SyncLiteDBAddress is the base URL for the API
var syncLiteDBAddress = "http://localhost:5555"

func buildAuthHeaders(requestBody []byte) map[string]string {
	headers := map[string]string{
		"Content-Type": "application/json",
	}

	if token := os.Getenv("SYNCLITE_DB_AUTH_TOKEN"); token != "" {
		headers["X-SyncLite-Token"] = token
	}

	appID := os.Getenv("SYNCLITE_DB_APP_ID")
	appSecret := os.Getenv("SYNCLITE_DB_APP_SECRET")
	if appID != "" && appSecret != "" {
		timestamp := fmt.Sprintf("%d", time.Now().UnixMilli())
		nonceBytes := make([]byte, 16)
		_, _ = rand.Read(nonceBytes)
		nonce := fmt.Sprintf("%x", nonceBytes)

		bodyHash := sha256.Sum256(requestBody)
		canonical := fmt.Sprintf("POST\n/\n%s\n%s\n%x", timestamp, nonce, bodyHash)

		mac := hmac.New(sha256.New, []byte(appSecret))
		mac.Write([]byte(canonical))
		signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))

		headers["X-SyncLite-App-Id"] = appID
		headers["X-SyncLite-Timestamp"] = timestamp
		headers["X-SyncLite-Nonce"] = nonce
		headers["X-SyncLite-Signature"] = signature
	}

	return headers
}

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
	for k, v := range buildAuthHeaders(requestBody) {
		req.Header.Set(k, v)
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return result, fmt.Errorf("failed to send request: %v", err)
	}
	defer resp.Body.Close()

	fmt.Println("Response Code:", resp.StatusCode)

	if resp.StatusCode == 200 || resp.StatusCode == 400 || resp.StatusCode == 401 || resp.StatusCode == 413 {
		body, _ := io.ReadAll(resp.Body)
		fmt.Println("Response JSON:", string(body))
		err = json.Unmarshal(body, &result)
		if err != nil {
			return result, fmt.Errorf("failed to parse JSON response: %v", err)
		}
	} else {
		body, _ := io.ReadAll(resp.Body)
		return result, fmt.Errorf("failed to get a valid response from the server: %v : %s", resp.StatusCode, string(body))
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
func executeSQL(dbPath, txnHandle, sql string, arguments [][]interface{}, dataFormat string, includeMetadata *bool) (SyncLiteDBResult, error) {
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
	if dataFormat != "" {
		jsonRequest["resultset-data-format"] = dataFormat
	}
	if includeMetadata != nil {
		if *includeMetadata {
			jsonRequest["resultset-include-metadata"] = "ON"
		} else {
			jsonRequest["resultset-include-metadata"] = "OFF"
		}
	}

	return processRequest(jsonRequest)
}

func next(resultsetHandle string, resultsetPaginationSize int, dataFormat string, includeMetadata *bool) (SyncLiteDBResult, error) {
	jsonRequest := map[string]interface{}{
		"request-type":     "next",
		"resultset-handle": resultsetHandle,
	}
	if resultsetPaginationSize > 0 {
		jsonRequest["resultset-pagination-size"] = resultsetPaginationSize
	}
	if dataFormat != "" {
		jsonRequest["resultset-data-format"] = dataFormat
	}
	if includeMetadata != nil {
		if *includeMetadata {
			jsonRequest["resultset-include-metadata"] = "ON"
		} else {
			jsonRequest["resultset-include-metadata"] = "OFF"
		}
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

	dbPath := filepath.Join(dbDir, "testGo.db")

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
	r, err = executeSQL(dbPath, txnHandle, "create table if not exists t1(a int, b text)", nil, "", nil)
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
	r, err = executeSQL(dbPath, txnHandle, "insert into t1 (a,b) values(?, ?)", arguments, "", nil)
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

	// Select from table (JSON format - default, records as map[colName]colValue)
	fmt.Println("========================================================")
	fmt.Println("Executing select from table (JSON format)")
	fmt.Println("========================================================")
	r, err = executeSQL(dbPath, "", "select a, b from t1", nil, "", nil)
	if err != nil {
		log.Fatalf("Failed to select from table: %v", err)
	}
	fmt.Printf("result: %v, message: %v\n", r.Result, r.Message)
	if len(r.ColumnMetadata) > 0 {
		for i, col := range r.ColumnMetadata {
			if i > 0 {
				fmt.Print("\t")
			}
			fmt.Print(col["label"])
		}
		fmt.Println()
	}
	for _, rec := range r.ResultSet {
		fmt.Printf("a = %v, b = %v\n", rec["a"], rec["b"])
	}
	for r.HasMore && r.ResultsetHandle != "" {
		r, err = next(r.ResultsetHandle, 0, "", nil)
		if err != nil {
			log.Fatalf("Failed to fetch next result page: %v", err)
		}
		if !r.Result {
			log.Fatalf("Next page call failed: %v", r.Message)
		}
		for _, rec := range r.ResultSet {
			fmt.Printf("a = %v, b = %v\n", rec["a"], rec["b"])
		}
	}
	fmt.Println("========================================================")

	// Select from table (DB format - records as []interface{} value arrays, column order matches ColumnMetadata)
	fmt.Println("========================================================")
	fmt.Println("Executing select from table (DB format)")
	fmt.Println("========================================================")
	includeMetadata := true
	dbFmtResult, err := executeSQL(dbPath, "", "select a, b from t1", nil, "DB", &includeMetadata)
	if err != nil {
		log.Fatalf("Failed to select from table (DB format): %v", err)
	}
	fmt.Printf("result: %v, message: %v\n", dbFmtResult.Result, dbFmtResult.Message)
	if len(dbFmtResult.ColumnMetadata) > 0 {
		for i, col := range dbFmtResult.ColumnMetadata {
			if i > 0 {
				fmt.Print("\t")
			}
			fmt.Print(col["label"])
		}
		fmt.Println()
	}
	for dbFmtResult.Result {
		for _, rowRaw := range dbFmtResult.ResultSet {
			// In DB format each "row" is deserialized as map[string]interface{} by Go's JSON,
			// but the values are positional by index key. Print all values in order.
			for i, col := range dbFmtResult.ColumnMetadata {
				if i > 0 {
					fmt.Print("\t")
				}
				fmt.Print(rowRaw[col["label"].(string)])
			}
			fmt.Println()
		}
		if !dbFmtResult.HasMore || dbFmtResult.ResultsetHandle == "" {
			break
		}
		dbFmtResult, err = next(dbFmtResult.ResultsetHandle, 0, "DB", nil)
		if err != nil {
			log.Fatalf("Failed to fetch next result page (DB format): %v", err)
		}
		if !dbFmtResult.Result {
			log.Fatalf("Next page call failed: %v", dbFmtResult.Message)
		}
	}
	fmt.Println("========================================================")

	// Drop table
	fmt.Println("========================================================")
	fmt.Println("Executing drop table")
	fmt.Println("========================================================")
	r, err = executeSQL(dbPath, "", "drop table t1", nil, "", nil)
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
