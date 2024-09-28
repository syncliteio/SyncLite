require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

=begin

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

=end

class SyncLiteDBResult
  attr_accessor :result, :message, :result_set, :txn_handle

  def initialize
    @result_set = []
  end
end

class SyncLiteDBClient
  SYNC_LITE_DB_ADDRESS = 'http://localhost:5555'
  DB_DIR = File.join(Dir.home, 'synclite', 'job1', 'db')

  def self.process_request(json_request)
    uri = URI(SYNC_LITE_DB_ADDRESS)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = json_request.to_json

    puts "Request JSON: #{json_request.to_json}"

    response = http.request(request)

    puts "Response Code: #{response.code}"
    raise "Failed to get a valid response from the server: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    json_response = JSON.parse(response.body)
    puts "Response JSON: #{json_response.to_json}"

    json_response
  rescue StandardError => e
    raise "Failed to process request: #{e.message}"
  end

  def self.initialize_db(db_path, db_type, db_name, sync_lite_logger_config_path = nil)
    json_request = {
      'db-path' => db_path.to_s,
      'db-type' => db_type,
      'db-name' => db_name,
      'sql' => 'initialize'
    }

	json_request['synclite-logger-config'] = sync_lite_logger_config_path.to_s unless sync_lite_logger_config_path.nil?

    json_response = process_request(json_request)
    result = SyncLiteDBResult.new
    result.result = json_response['result']
    result.message = json_response['message']
    result
  end

  def self.begin_transaction(db_path)
    json_request = {
      'db-path' => db_path.to_s,
      'sql' => 'begin'
    }

    json_response = process_request(json_request)
    result = SyncLiteDBResult.new
    result.result = json_response['result']
    result.message = json_response['message']
    result.txn_handle = json_response['txn-handle']
    result
  end

  def self.commit_transaction(db_path, txn_handle)
    json_request = {
      'db-path' => db_path.to_s,
      'txn-handle' => txn_handle,
      'sql' => 'commit'
    }

    json_response = process_request(json_request)
    result = SyncLiteDBResult.new
    result.result = json_response['result']
    result.message = json_response['message']
    result
  end

  def self.rollback_transaction(db_path, txn_handle)
    json_request = {
      'db-path' => db_path.to_s,
      'txn-handle' => txn_handle,
      'sql' => 'rollback'
    }

    json_response = process_request(json_request)
    result = SyncLiteDBResult.new
    result.result = json_response['result']
    result.message = json_response['message']
    result
  end

  def self.execute_sql(db_path, txn_handle, sql, arguments = nil)
    json_request = {
      'db-path' => db_path.to_s,
      'sql' => sql,
      'arguments' => arguments
    }.compact

	json_request['txn-handle'] = txn_handle.to_s unless txn_handle.nil?

    json_response = process_request(json_request)
    result = SyncLiteDBResult.new
    result.result = json_response['result']
    result.message = json_response['message']
    result.result_set = json_response['resultset'] if json_response.key?('resultset')
    result
  end

  def self.close_db(db_path)
    json_request = {
      'db-path' => db_path.to_s,
      'sql' => 'close'
    }

    json_response = process_request(json_request)
    result = SyncLiteDBResult.new
    result.result = json_response['result']
    result.message = json_response['message']
    result
  end

  def self.create_db_dirs
    FileUtils.mkdir_p(DB_DIR)
  end

  def self.run
    create_db_dirs
    db_path = File.join(DB_DIR, 'testRuby.db')

    puts "========================================================"
    puts "Executing initialize DB"
    puts "========================================================"
    r = initialize_db(db_path, 'SQLITE', 'testRuby')
    puts "result: #{r.result}, message: #{r.message}"
    exit(1) unless r.result

    puts "========================================================"
    puts "Executing begin transaction"
    puts "========================================================"
    r = begin_transaction(db_path)
    puts "result: #{r.result}, message: #{r.message}, txn-handle: #{r.txn_handle}"
    txn_handle = r.txn_handle
    exit(1) unless r.result

    puts "========================================================"
    puts "Executing create table"
    puts "========================================================"
    r = execute_sql(db_path, txn_handle, 'create table if not exists t1(a int, b text)')
    puts "result: #{r.result}, message: #{r.message}"
    exit(1) unless r.result

    puts "========================================================"
    puts "Executing insert into table"
    puts "========================================================"
    arguments = [
      [1, 'one'],
      [2, 'two']
    ]

    r = execute_sql(db_path, txn_handle, 'insert into t1 (a,b) values(?, ?)', arguments)
    puts "result: #{r.result}, message: #{r.message}"
    exit(1) unless r.result

    puts "========================================================"
    puts "Executing commit transaction"
    puts "========================================================"
    r = commit_transaction(db_path, txn_handle)
    puts "result: #{r.result}, message: #{r.message}"
    exit(1) unless r.result

    puts "========================================================"
    puts "Executing select from table"
    puts "========================================================"
    r = execute_sql(db_path, nil, 'select a, b from t1')
    puts "result: #{r.result}, message: #{r.message}"

    puts "Selected Records:"
    r.result_set.each do |rec|
      puts "a = #{rec['a']}, b = #{rec['b']}"
    end

    puts "========================================================"
    puts "Executing drop table"
    puts "========================================================"
    r = execute_sql(db_path, nil, 'drop table t1')
    puts "result: #{r.result}, message: #{r.message}"

    puts "========================================================"
    puts "Executing close DB"
    puts "========================================================"
    r = close_db(db_path)
    puts "result: #{r.result}, message: #{r.message}"
    puts "========================================================"
  end
end

SyncLiteDBClient.run
