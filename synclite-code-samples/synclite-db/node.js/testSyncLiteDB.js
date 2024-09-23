const axios = require('axios');
const path = require('path');
const fs = require('fs').promises;

/*
* ===========================================================
  Note: 
* ===========================================================
Install required modules.

npm install axios
npm install path
npm install fs


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

const syncLiteDBAddress = 'http://localhost:5555';
let dbDir;

class SyncLiteDBResult {
  constructor() {
    this.result = false;
    this.message = '';
    this.resultSet = [];
    this.txnHandle = '';
  }
}

async function processRequest(jsonRequest) {
  try {
    console.log('Request JSON:', JSON.stringify(jsonRequest, null, 4));
    const response = await axios.post(syncLiteDBAddress, jsonRequest, {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 10000,
    });

    console.log('Response Code:', response.status);
    console.log('Response JSON:', JSON.stringify(response.data, null, 4));

    const jsonResponse = response.data;

    if (response.status === 200 && jsonResponse.result === true) {
      console.log('Result:', jsonResponse.result);
      console.log('Message:', jsonResponse.message);
      return jsonResponse;
    } else {
      throw new Error('Failed to get a valid response from the server');
    }
  } catch (error) {
    throw new Error(`Failed to process request: ${error.message}`);
  }
}

async function initializeDB(dbPath, dbType, dbName, syncLiteLoggerConfigPath) {
  try {
    const jsonRequest = {
      'db-path': dbPath,
      'db-type': dbType,
      'db-name': dbName,
      'sql': 'initialize',
    };

    if (syncLiteLoggerConfigPath) {
      jsonRequest['synclite-logger-config'] = syncLiteLoggerConfigPath;
    }

    const jsonResponse = await processRequest(jsonRequest);
    const dbResult = new SyncLiteDBResult();
    dbResult.result = jsonResponse.result;
    dbResult.message = jsonResponse.message;

    return dbResult;
  } catch (error) {
    throw new Error(`Failed to initialize DB: ${dbPath}: ${error.message}`);
  }
}

async function beginTransaction(dbPath) {
  try {
    const jsonRequest = {
      'db-path': dbPath,
      'sql': 'begin',
    };

    const jsonResponse = await processRequest(jsonRequest);
    const dbResult = new SyncLiteDBResult();
    dbResult.result = jsonResponse.result;
    dbResult.message = jsonResponse.message;
    dbResult.txnHandle = jsonResponse['txn-handle'];

    return dbResult;
  } catch (error) {
    throw new Error(`Failed to begin transaction on DB: ${dbPath}: ${error.message}`);
  }
}

async function commitTransaction(dbPath, txnHandle) {
  try {
    const jsonRequest = {
      'db-path': dbPath,
      'txn-handle': txnHandle,
      'sql': 'commit',
    };

    const jsonResponse = await processRequest(jsonRequest);
    const dbResult = new SyncLiteDBResult();
    dbResult.result = jsonResponse.result;
    dbResult.message = jsonResponse.message;

    return dbResult;
  } catch (error) {
    throw new Error(`Failed to commit transaction on DB: ${dbPath}: ${error.message}`);
  }
}

async function rollbackTransaction(dbPath) {
  try {
    const jsonRequest = {
      'db-path': dbPath,
      'sql': 'rollback',
    };

    const jsonResponse = await processRequest(jsonRequest);
    const dbResult = new SyncLiteDBResult();
    dbResult.result = jsonResponse.result;
    dbResult.message = jsonResponse.message;

    return dbResult;
  } catch (error) {
    throw new Error(`Failed to rollback transaction on DB: ${dbPath}: ${error.message}`);
  }
}

async function executeSQL(dbPath, txnHandle, sql, arguments = null) {
  try {
    const jsonRequest = {
      'db-path': dbPath,
      'sql': sql,
    };

    if (txnHandle) {
      jsonRequest['txn-handle'] = txnHandle;
    }

    if (arguments) {
      jsonRequest['arguments'] = arguments;
    }

    const jsonResponse = await processRequest(jsonRequest);
    const dbResult = new SyncLiteDBResult();
    dbResult.result = jsonResponse.result;
    dbResult.message = jsonResponse.message;

    if (jsonResponse.resultset) {
      dbResult.resultSet = jsonResponse.resultset;
    }

    return dbResult;
  } catch (error) {
    throw new Error(`Failed to execute SQL on DB: ${dbPath}: ${error.message}`);
  }
}

async function closeDB(dbPath) {
  try {
    const jsonRequest = {
      'db-path': dbPath,
      'sql': 'close',
    };

    const jsonResponse = await processRequest(jsonRequest);
    const dbResult = new SyncLiteDBResult();
    dbResult.result = jsonResponse.result;
    dbResult.message = jsonResponse.message;

    return dbResult;
  } catch (error) {
    throw new Error(`Failed to close DB: ${dbPath}: ${error.message}`);
  }
}

async function createDBDirs() {
  try {
    const userHome = process.env.HOME || process.env.USERPROFILE;
    dbDir = path.join(userHome, 'synclite', 'job1', 'db');
    await fs.mkdir(dbDir, { recursive: true });
  } catch (error) {
    throw new Error(`Failed to create DB directories: ${error.message}`);
  }
}

(async () => {
  try {
    await createDBDirs();
    const dbPath = path.join(dbDir, 'testJava');

    // Initialize DB
    console.log('========================================================');
    console.log('Executing initialize DB');
    console.log('========================================================');
    let r = await initializeDB(dbPath, 'SQLITE', 'testNodeJS', null);
    console.log('result :', r.result);
    console.log('message :', r.message);
    if (!r.result) process.exit(1);

    // Begin Transaction
    console.log('========================================================');
    console.log('Executing begin transaction');
    console.log('========================================================');
    r = await beginTransaction(dbPath);
    console.log('result :', r.result);
    console.log('message :', r.message);
    const txnHandle = r.txnHandle;
    console.log('txn-handle:', txnHandle);
    if (!r.result) process.exit(1);

    // Create Table
    console.log('========================================================');
    console.log('Executing create table');
    console.log('========================================================');
    r = await executeSQL(dbPath, txnHandle, 'CREATE TABLE IF NOT EXISTS t1(a INT, b TEXT)');
    console.log('result :', r.result);
    console.log('message :', r.message);
    if (!r.result) process.exit(1);

    // Insert Data
    console.log('========================================================');
    console.log('Executing insert into table');
    console.log('========================================================');
    const arguments = [
      [1, 'one'],
      [2, 'two'],
    ];
    r = await executeSQL(dbPath, txnHandle, 'INSERT INTO t1 (a, b) VALUES (?, ?)', arguments);
    console.log('result :', r.result);
    console.log('message :', r.message);
    if (!r.result) process.exit(1);

    // Commit Transaction
    console.log('========================================================');
    console.log('Executing commit transaction');
    console.log('========================================================');
    r = await commitTransaction(dbPath, txnHandle);
    console.log('result :', r.result);
    console.log('message :', r.message);
    if (!r.result) process.exit(1);

    // Select Data
    console.log('========================================================');
    console.log('Executing select from table');
    console.log('========================================================');
    r = await executeSQL(dbPath, null, 'SELECT a, b FROM t1');
    console.log('result :', r.result);
    console.log('message :', r.message);
    console.log('Selected Records:');
    r.resultSet.forEach((record) => {
      console.log('a =', record.a, ', b =', record.b);
    });

    // Drop Table
    console.log('========================================================');
    console.log('Executing drop table');
    console.log('========================================================');
    r = await executeSQL(dbPath, null, 'DROP TABLE t1');
    console.log('result :', r.result);
    console.log('message :', r.message);

    // Close DB
    console.log('========================================================');
    console.log('Executing close DB');
    console.log('========================================================');
    r = await closeDB(dbPath);
    console.log('result :', r.result);
    console.log('message :', r.message);
  } catch (error) {
    console.error('Error:', error.message);
  }
})();
