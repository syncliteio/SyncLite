#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <curl/curl.h>
#include <nlohmann/json.hpp>
#include <filesystem>
#include <stdexcept>

using json = nlohmann::json;
namespace fs = std::filesystem;

/*
* ===========================================================
  Note: 
* ===========================================================
Install dependencies

git clone https://github.com/microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install
.\vcpkg install curl
.\vcpkg install nlohmann-json


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


struct SyncLiteDBResult {
    bool result;
    std::string message;
    json resultSet;
    std::string txnHandle;
};

// Global variables
std::string syncLiteDBAddress = "http://localhost:5555";
fs::path dbDir;

// Helper function to perform HTTP POST requests
size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    ((std::string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

json processRequest(const json& jsonRequest) {
    CURL* curl;
    CURLcode res;
    std::string readBuffer;

    curl = curl_easy_init();
    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, syncLiteDBAddress.c_str());
        curl_easy_setopt(curl, CURLOPT_POST, 1L);

        std::string jsonStr = jsonRequest.dump();

        std::cout << "Request JSON:\n" << jsonStr << std::endl;

        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, jsonStr.c_str());

        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);

        struct curl_slist* headers = nullptr;
        headers = curl_slist_append(headers, "Content-Type: application/json");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

        res = curl_easy_perform(curl);
        if (res != CURLE_OK) {
            throw std::runtime_error("Failed to process request: " + std::string(curl_easy_strerror(res)));
        }

        curl_easy_cleanup(curl);

        json::parse(readBuffer);

        json jsonResponse = json::parse(readBuffer);

        std::cout << "Response JSON:\n" << readBuffer << std::endl;

        return jsonResponse;
    }
    else {
        throw std::runtime_error("Failed to initialize CURL");
    }
}

SyncLiteDBResult initializeDB(const fs::path& dbPath, const std::string& dbType, const std::string& dbName, const std::string& syncLiteLoggerConfigPath) {
    SyncLiteDBResult dbResult;
    try {
        json jsonRequest;
        jsonRequest["db-path"] = dbPath.string();
        jsonRequest["db-type"] = dbType;
        jsonRequest["db-name"] = dbName;
        if (!syncLiteLoggerConfigPath.empty()) {
            jsonRequest["synclite-logger-config"] = syncLiteLoggerConfigPath;
        }
        jsonRequest["sql"] = "initialize";

        json jsonResponse = processRequest(jsonRequest);

        dbResult.result = jsonResponse["result"];
        dbResult.message = jsonResponse["message"];
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to initialize DB: " + dbPath.string() + " : " + e.what());
    }
    return dbResult;
}

SyncLiteDBResult beginTransaction(const fs::path& dbPath) {
    SyncLiteDBResult dbResult;
    try {
        json jsonRequest;
        jsonRequest["db-path"] = dbPath.string();
        jsonRequest["sql"] = "begin";

        json jsonResponse = processRequest(jsonRequest);

        dbResult.result = jsonResponse["result"];
        dbResult.message = jsonResponse["message"];
        dbResult.txnHandle = jsonResponse["txn-handle"];
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to begin transaction on DB: " + dbPath.string() + " : " + e.what());
    }
    return dbResult;
}

SyncLiteDBResult commitTransaction(const fs::path& dbPath, const std::string& txnHandle) {
    SyncLiteDBResult dbResult;
    try {
        json jsonRequest;
        jsonRequest["db-path"] = dbPath.string();
        jsonRequest["txn-handle"] = txnHandle;
        jsonRequest["sql"] = "commit";

        json jsonResponse = processRequest(jsonRequest);

        dbResult.result = jsonResponse["result"];
        dbResult.message = jsonResponse["message"];
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to commit transaction on DB: " + dbPath.string() + " : " + e.what());
    }
    return dbResult;
}

SyncLiteDBResult rollbackTransaction(const fs::path& dbPath) {
    SyncLiteDBResult dbResult;
    try {
        json jsonRequest;
        jsonRequest["db-path"] = dbPath.string();
        jsonRequest["sql"] = "rollback";

        json jsonResponse = processRequest(jsonRequest);

        dbResult.result = jsonResponse["result"];
        dbResult.message = jsonResponse["message"];
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to rollback transaction on DB: " + dbPath.string() + " : " + e.what());
    }
    return dbResult;
}

SyncLiteDBResult executeSQL(const fs::path& dbPath, const std::string& txnHandle, const std::string& sql, const json& arguments) {
    SyncLiteDBResult dbResult;
    try {
        json jsonRequest;
        jsonRequest["db-path"] = dbPath.string();
        jsonRequest["sql"] = sql;
        if (!txnHandle.empty()) {
            jsonRequest["txn-handle"] = txnHandle;
        }
        if (!arguments.empty()) {
            jsonRequest["arguments"] = arguments;
        }

        json jsonResponse = processRequest(jsonRequest);

        dbResult.result = jsonResponse["result"];
        dbResult.message = jsonResponse["message"];
        if (jsonResponse.contains("resultset")) {
            dbResult.resultSet = jsonResponse["resultset"];
        }
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to execute SQL on DB: " + dbPath.string() + " : " + e.what());
    }
    return dbResult;
}

SyncLiteDBResult closeDB(const fs::path& dbPath) {
    SyncLiteDBResult dbResult;
    try {
        json jsonRequest;
        jsonRequest["db-path"] = dbPath.string();
        jsonRequest["sql"] = "close";

        json jsonResponse = processRequest(jsonRequest);

        dbResult.result = jsonResponse["result"];
        dbResult.message = jsonResponse["message"];
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to close DB: " + dbPath.string() + " : " + e.what());
    }
    return dbResult;
}

#include <cstdlib>
#include <iostream>
std::string getHomeDirectory() {
    char* homeDir = nullptr;
    size_t len = 0;

    // Use _dupenv_s to safely get the HOME environment variable
    _dupenv_s(&homeDir, &len, "USERPROFILE");

    std::string result;
    if (homeDir != nullptr) {
        result = std::string(homeDir);
        free(homeDir); // Free the memory allocated by _dupenv_s
    }
    else {
        throw std::runtime_error("Failed to get HOME environment variable");
    }

    return result;
}

void createDBDirs() {
    dbDir = fs::path(getHomeDirectory()) / "synclite" / "job1" / "db";
    fs::create_directories(dbDir);
}

int main() {
    try {
        createDBDirs();
        fs::path dbPath = dbDir / "testCpp";

        // Initialize DB
        std::cout << "========================================================\n";
        std::cout << "Executing initialize DB\n";
        std::cout << "========================================================\n";
        SyncLiteDBResult r = initializeDB(dbPath, "SQLITE", "testCpp", "");
        std::cout << "result: " << r.result << "\n";
        std::cout << "message: " << r.message << "\n";
        if (!r.result) {
            return 1;
        }

        // Begin transaction
        std::cout << "========================================================\n";
        std::cout << "Executing begin transaction\n";
        std::cout << "========================================================\n";
        r = beginTransaction(dbPath);
        std::string txn_handle = r.txnHandle;
        std::cout << "result: " << r.result << "\n";
        std::cout << "message: " << r.message << "\n";
        std::cout << "txn-handle: " << r.txnHandle << "\n";
        if (!r.result) {
            return 1;
        }

        // Create table
        std::cout << "========================================================\n";
        std::cout << "Executing create table\n";
        std::cout << "========================================================\n";
        r = executeSQL(dbPath, txn_handle, "create table if not exists t1(a int, b text)", {});
        std::cout << "result: " << r.result << "\n";
        std::cout << "message: " << r.message << "\n";
        if (!r.result) {
            return 1;
        }

        // Insert into table
        std::cout << "========================================================\n";
        std::cout << "Executing insert into table\n";
        std::cout << "========================================================\n";
        json arguments = json::array({ {1, "one"}, {2, "two"} });
        r = executeSQL(dbPath, txn_handle, "insert into t1 (a, b) values(?, ?)", arguments);
        std::cout << "result: " << r.result << "\n";
        std::cout << "message: " << r.message << "\n";
        if (!r.result) {
            return 1;
        }

        // Commit transaction
        std::cout << "========================================================\n";
        std::cout << "Executing commit transaction\n";
        std::cout << "========================================================\n";
        r = commitTransaction(dbPath, txn_handle);
        std::cout << "result: " << r.result << "\n";
        std::cout << "message: " << r.message << "\n";
        if (!r.result) {
            return 1;
        }

        // Execute select
        std::cout << "========================================================\n";
        std::cout << "Executing select from table\n";
        std::cout << "========================================================\n";
        r = executeSQL(dbPath, "", "select * from t1", {});
        std::cout << "result: " << r.result << "\n";
        std::cout << "message: " << r.message << "\n";
        std::cout << "resultSet: " << r.resultSet.dump(4) << "\n";
        if (!r.result) {
            return 1;
        }

        // Close DB
        std::cout << "========================================================\n";
        std::cout << "Executing close DB\n";
        std::cout << "========================================================\n";
        r = closeDB(dbPath);
        std::cout << "result: " << r.result << "\n";
        std::cout << "message: " << r.message << "\n";
        if (!r.result) {
            return 1;
        }

    }
    catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
