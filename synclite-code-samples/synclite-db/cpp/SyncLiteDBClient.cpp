#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <iomanip>
#include <chrono>
#include <random>
#include <array>
#include <curl/curl.h>
#include <nlohmann/json.hpp>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/sha.h>
#include <filesystem>
#include <stdexcept>
#include <cstdlib>

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
.\vcpkg install openssl


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
    std::string resultsetHandle;
    bool hasMore = false;
    json columnMetadata;
};

static SyncLiteDBResult toDBResult(const json& jsonResponse) {
    SyncLiteDBResult dbResult{};
    dbResult.result = jsonResponse.value("result", false);
    dbResult.message = jsonResponse.value("message", "");
    if (jsonResponse.contains("resultset")) {
        dbResult.resultSet = jsonResponse["resultset"];
    }
    if (jsonResponse.contains("txn-handle")) {
        dbResult.txnHandle = jsonResponse["txn-handle"].get<std::string>();
    }
    if (jsonResponse.contains("resultset-handle")) {
        dbResult.resultsetHandle = jsonResponse["resultset-handle"].get<std::string>();
    }
    if (jsonResponse.contains("has-more")) {
        dbResult.hasMore = jsonResponse["has-more"].get<bool>();
    }
    if (jsonResponse.contains("resultset-metadata")) {
        dbResult.columnMetadata = jsonResponse["resultset-metadata"];
    }
    return dbResult;
}

// Global variables
std::string syncLiteDBAddress = "http://localhost:5555";
fs::path dbDir;

// Helper function to perform HTTP POST requests
size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    ((std::string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

static bool hasValue(const char* value) {
    return value != nullptr && std::string(value).size() > 0;
}

static std::string sha256Hex(const std::string& value) {
    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256(reinterpret_cast<const unsigned char*>(value.data()), value.size(), hash);

    std::ostringstream out;
    out << std::hex << std::setfill('0');
    for (unsigned char b : hash) {
        out << std::setw(2) << static_cast<int>(b);
    }
    return out.str();
}

static std::string hmacSha256Base64(const std::string& secret, const std::string& payload) {
    unsigned int macLen = 0;
    unsigned char* mac = HMAC(
        EVP_sha256(),
        secret.data(),
        static_cast<int>(secret.size()),
        reinterpret_cast<const unsigned char*>(payload.data()),
        payload.size(),
        nullptr,
        &macLen);

    if (mac == nullptr || macLen == 0) {
        throw std::runtime_error("Failed to compute HMAC-SHA256 signature");
    }

    std::string encoded;
    encoded.resize(4 * ((macLen + 2) / 3));
    int encodedLen = EVP_EncodeBlock(
        reinterpret_cast<unsigned char*>(&encoded[0]),
        mac,
        macLen);

    if (encodedLen < 0) {
        throw std::runtime_error("Failed to base64-encode signature");
    }

    encoded.resize(static_cast<size_t>(encodedLen));
    return encoded;
}

static std::string generateNonce() {
    std::array<unsigned char, 16> bytes{};
    std::random_device rd;
    for (auto& b : bytes) {
        b = static_cast<unsigned char>(rd());
    }

    std::ostringstream out;
    out << std::hex << std::setfill('0');
    for (unsigned char b : bytes) {
        out << std::setw(2) << static_cast<int>(b);
    }
    return out.str();
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

        const char* token = std::getenv("SYNCLITE_DB_AUTH_TOKEN");
        if (hasValue(token)) {
            headers = curl_slist_append(headers, (std::string("X-SyncLite-Token: ") + token).c_str());
        }

        const char* appId = std::getenv("SYNCLITE_DB_APP_ID");
        const char* appSecret = std::getenv("SYNCLITE_DB_APP_SECRET");
        if (hasValue(appId) && hasValue(appSecret)) {
            long long nowMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count();
            std::string appTimestamp = std::to_string(nowMs);
            std::string appNonce = generateNonce();
            std::string canonical = "POST\n/\n" + appTimestamp + "\n" + appNonce + "\n" + sha256Hex(jsonStr);
            std::string appSignature = hmacSha256Base64(appSecret, canonical);

            headers = curl_slist_append(headers, (std::string("X-SyncLite-App-Id: ") + appId).c_str());
            headers = curl_slist_append(headers, (std::string("X-SyncLite-Timestamp: ") + appTimestamp).c_str());
            headers = curl_slist_append(headers, (std::string("X-SyncLite-Nonce: ") + appNonce).c_str());
            headers = curl_slist_append(headers, (std::string("X-SyncLite-Signature: ") + appSignature).c_str());
        } else {
            const char* appTimestamp = std::getenv("SYNCLITE_DB_APP_TIMESTAMP");
            const char* appNonce = std::getenv("SYNCLITE_DB_APP_NONCE");
            const char* appSignature = std::getenv("SYNCLITE_DB_APP_SIGNATURE");
            if (hasValue(appId) && hasValue(appTimestamp) && hasValue(appNonce) && hasValue(appSignature)) {
                headers = curl_slist_append(headers, (std::string("X-SyncLite-App-Id: ") + appId).c_str());
                headers = curl_slist_append(headers, (std::string("X-SyncLite-Timestamp: ") + appTimestamp).c_str());
                headers = curl_slist_append(headers, (std::string("X-SyncLite-Nonce: ") + appNonce).c_str());
                headers = curl_slist_append(headers, (std::string("X-SyncLite-Signature: ") + appSignature).c_str());
            }
        }

        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

        res = curl_easy_perform(curl);
        if (res != CURLE_OK) {
            std::string err = "Failed to process request: " + std::string(curl_easy_strerror(res));
            curl_slist_free_all(headers);
            curl_easy_cleanup(curl);
            throw std::runtime_error(err);
        }

        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);

        json jsonResponse = json::parse(readBuffer);

        std::cout << "Response JSON:\n" << readBuffer << std::endl;

        return jsonResponse;
    }
    else {
        throw std::runtime_error("Failed to initialize CURL");
    }
}

SyncLiteDBResult initializeDB(const fs::path& dbPath, const std::string& dbType, const std::string& dbName, const std::string& syncLiteLoggerConfigPath) {
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

        return toDBResult(jsonResponse);
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to initialize DB: " + dbPath.string() + " : " + e.what());
    }
}

SyncLiteDBResult beginTransaction(const fs::path& dbPath) {
    try {
        json jsonRequest;
        jsonRequest["db-path"] = dbPath.string();
        jsonRequest["sql"] = "begin";

        json jsonResponse = processRequest(jsonRequest);

        return toDBResult(jsonResponse);
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to begin transaction on DB: " + dbPath.string() + " : " + e.what());
    }
}

SyncLiteDBResult commitTransaction(const fs::path& dbPath, const std::string& txnHandle) {
    try {
        json jsonRequest;
        jsonRequest["db-path"] = dbPath.string();
        jsonRequest["txn-handle"] = txnHandle;
        jsonRequest["sql"] = "commit";

        json jsonResponse = processRequest(jsonRequest);

        return toDBResult(jsonResponse);
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to commit transaction on DB: " + dbPath.string() + " : " + e.what());
    }
}

SyncLiteDBResult rollbackTransaction(const fs::path& dbPath, const std::string& txnHandle) {
    try {
        json jsonRequest;
        jsonRequest["db-path"] = dbPath.string();
        jsonRequest["txn-handle"] = txnHandle;
        jsonRequest["sql"] = "rollback";

        json jsonResponse = processRequest(jsonRequest);

        return toDBResult(jsonResponse);
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to rollback transaction on DB: " + dbPath.string() + " : " + e.what());
    }
}

SyncLiteDBResult executeSQL(const fs::path& dbPath, const std::string& txnHandle, const std::string& sql, const json& arguments, const std::string& dataFormat, bool includeMetadata) {
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
        if (!dataFormat.empty()) {
            jsonRequest["resultset-data-format"] = dataFormat;
        }
        jsonRequest["resultset-include-metadata"] = includeMetadata ? "ON" : "OFF";

        json jsonResponse = processRequest(jsonRequest);

        return toDBResult(jsonResponse);
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to execute SQL on DB: " + dbPath.string() + " : " + e.what());
    }
}

SyncLiteDBResult executeSQL(const fs::path& dbPath, const std::string& txnHandle, const std::string& sql, const json& arguments) {
    return executeSQL(dbPath, txnHandle, sql, arguments, "", true);
}

SyncLiteDBResult next(const std::string& resultsetHandle, int resultsetPaginationSize, const std::string& dataFormat, bool includeMetadata) {
    try {
        json jsonRequest;
        jsonRequest["request-type"] = "next";
        jsonRequest["resultset-handle"] = resultsetHandle;
        if (resultsetPaginationSize > 0) {
            jsonRequest["resultset-pagination-size"] = resultsetPaginationSize;
        }
        if (!dataFormat.empty()) {
            jsonRequest["resultset-data-format"] = dataFormat;
        }
        jsonRequest["resultset-include-metadata"] = includeMetadata ? "ON" : "OFF";

        json jsonResponse = processRequest(jsonRequest);
        return toDBResult(jsonResponse);
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to fetch next page for resultset-handle: " + resultsetHandle + " : " + e.what());
    }
}

SyncLiteDBResult next(const std::string& resultsetHandle, int resultsetPaginationSize) {
    return next(resultsetHandle, resultsetPaginationSize, "", true);
}

SyncLiteDBResult closeDB(const fs::path& dbPath) {
    try {
        json jsonRequest;
        jsonRequest["db-path"] = dbPath.string();
        jsonRequest["sql"] = "close";

        json jsonResponse = processRequest(jsonRequest);

        return toDBResult(jsonResponse);
    }
    catch (const std::exception& e) {
        throw std::runtime_error("Failed to close DB: " + dbPath.string() + " : " + e.what());
    }
}

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
        fs::path dbPath = dbDir / "testCpp.db";

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

        // Execute select (JSON format - default, records as {colName: colValue} objects)
        std::cout << "========================================================\n";
        std::cout << "Executing select from table (JSON format)\n";
        std::cout << "========================================================\n";
        r = executeSQL(dbPath, "", "select * from t1", {});
        std::cout << "result: " << r.result << "\n";
        std::cout << "message: " << r.message << "\n";
        if (!r.result) {
            return 1;
        }
        if (!r.columnMetadata.is_null() && r.columnMetadata.is_array()) {
            bool first = true;
            for (const auto& col : r.columnMetadata) {
                if (!first) std::cout << "\t";
                std::cout << col.value("label", "");
                first = false;
            }
            std::cout << "\n";
        }
        {
            SyncLiteDBResult current = r;
            while (true) {
                if (!current.resultSet.is_null()) {
                    for (const auto& rec : current.resultSet) {
                        std::cout << "a = " << rec.value("a", json(nullptr)) << ", b = " << rec.value("b", json(nullptr)) << "\n";
                    }
                }

                if (!current.hasMore || current.resultsetHandle.empty()) {
                    break;
                }

                current = next(current.resultsetHandle, 0);
                if (!current.result) {
                    throw std::runtime_error("Next page call failed: " + current.message);
                }
            }
        }

        // Execute select (DB format - records as value arrays, column order matches columnMetadata)
        std::cout << "========================================================\n";
        std::cout << "Executing select from table (DB format)\n";
        std::cout << "========================================================\n";
        r = executeSQL(dbPath, "", "select * from t1", {}, "DB", true);
        std::cout << "result: " << r.result << "\n";
        std::cout << "message: " << r.message << "\n";
        if (!r.columnMetadata.is_null() && r.columnMetadata.is_array()) {
            bool first = true;
            for (const auto& col : r.columnMetadata) {
                if (!first) std::cout << "\t";
                std::cout << col.value("label", "");
                first = false;
            }
            std::cout << "\n";
        }
        {
            SyncLiteDBResult current = r;
            while (true) {
                if (!current.resultSet.is_null()) {
                    for (const auto& row : current.resultSet) {
                        bool first = true;
                        for (const auto& val : row) {
                            if (!first) std::cout << "\t";
                            std::cout << val;
                            first = false;
                        }
                        std::cout << "\n";
                    }
                }

                if (!current.hasMore || current.resultsetHandle.empty()) {
                    break;
                }

                current = next(current.resultsetHandle, 0, "DB", true);
                if (!current.result) {
                    throw std::runtime_error("Next page call failed: " + current.message);
                }
            }
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
