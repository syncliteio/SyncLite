require 'net/http'
require 'json'
require 'uri'
require 'fileutils'
require 'openssl'
require 'base64'
require 'securerandom'

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
  attr_accessor :result, :message, :result_set, :txn_handle, :resultset_handle, :has_more, :column_metadata

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
    payload = json_request.to_json
    request.body = payload

    token = ENV['SYNCLITE_DB_AUTH_TOKEN']
    request['X-SyncLite-Token'] = token unless token.nil? || token.empty?

    app_id = ENV['SYNCLITE_DB_APP_ID']
    app_secret = ENV['SYNCLITE_DB_APP_SECRET']
    unless app_id.nil? || app_id.empty? || app_secret.nil? || app_secret.empty?
      timestamp = (Time.now.to_f * 1000).to_i.to_s
      nonce = SecureRandom.uuid
      body_hash = OpenSSL::Digest::SHA256.hexdigest(payload)
      canonical = "POST\n/\n#{timestamp}\n#{nonce}\n#{body_hash}"
      signature = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', app_secret, canonical))

      request['X-SyncLite-App-Id'] = app_id
      request['X-SyncLite-Timestamp'] = timestamp
      request['X-SyncLite-Nonce'] = nonce
      request['X-SyncLite-Signature'] = signature
    end

    puts "Request JSON: #{json_request.to_json}"

    response = http.request(request)

    puts "Response Code: #{response.code}"
    unless [200, 400, 401, 413].include?(response.code.to_i)
      raise "Failed to get a valid response from the server: #{response.code}"
    end

    json_response = JSON.parse(response.body)
    puts "Response JSON: #{json_response.to_json}"

    json_response
  rescue StandardError => e
    raise "Failed to process request: #{e.message}"
  end

  def self.to_db_result(json_response)
    result = SyncLiteDBResult.new
    result.result = json_response['result']
    result.message = json_response['message']
    result.result_set = json_response['resultset'] if json_response.key?('resultset')
    result.txn_handle = json_response['txn-handle'] if json_response.key?('txn-handle')
    result.resultset_handle = json_response['resultset-handle'] if json_response.key?('resultset-handle')
    result.has_more = json_response['has-more'] if json_response.key?('has-more')
    result.column_metadata = json_response['resultset-metadata'] if json_response.key?('resultset-metadata')
    result
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
    to_db_result(json_response)
  end

  def self.begin_transaction(db_path)
    json_request = {
      'db-path' => db_path.to_s,
      'sql' => 'begin'
    }

    json_response = process_request(json_request)
    to_db_result(json_response)
  end

  def self.commit_transaction(db_path, txn_handle)
    json_request = {
      'db-path' => db_path.to_s,
      'txn-handle' => txn_handle,
      'sql' => 'commit'
    }

    json_response = process_request(json_request)
    to_db_result(json_response)
  end

  def self.rollback_transaction(db_path, txn_handle)
    json_request = {
      'db-path' => db_path.to_s,
      'txn-handle' => txn_handle,
      'sql' => 'rollback'
    }

    json_response = process_request(json_request)
    to_db_result(json_response)
  end

  def self.execute_sql(db_path, txn_handle, sql, arguments = nil, data_format: nil, include_metadata: nil)
    json_request = {
      'db-path' => db_path.to_s,
      'sql' => sql,
      'arguments' => arguments
    }.compact

	json_request['txn-handle'] = txn_handle.to_s unless txn_handle.nil?
    json_request['resultset-data-format'] = data_format unless data_format.nil?
    json_request['resultset-include-metadata'] = include_metadata ? 'ON' : 'OFF' unless include_metadata.nil?

    json_response = process_request(json_request)
    to_db_result(json_response)
  end

  def self.next_page(resultset_handle, resultset_pagination_size = nil, data_format: nil, include_metadata: nil)
    json_request = {
      'request-type' => 'next',
      'resultset-handle' => resultset_handle
    }
    json_request['resultset-pagination-size'] = resultset_pagination_size if !resultset_pagination_size.nil? && resultset_pagination_size.to_i > 0
    json_request['resultset-data-format'] = data_format unless data_format.nil?
    json_request['resultset-include-metadata'] = include_metadata ? 'ON' : 'OFF' unless include_metadata.nil?

    json_response = process_request(json_request)
    to_db_result(json_response)
  end

  def self.close_db(db_path)
    json_request = {
      'db-path' => db_path.to_s,
      'sql' => 'close'
    }

    json_response = process_request(json_request)
    to_db_result(json_response)
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
    puts "Executing select from table (JSON format)"
    puts "========================================================"
    r = execute_sql(db_path, nil, 'select a, b from t1')
    puts "result: #{r.result}, message: #{r.message}"

    if r.column_metadata
      puts r.column_metadata.map { |c| c['label'] }.join("\t")
    end
    current = r
    loop do
      current.result_set.each do |rec|
        puts "a = #{rec['a']}, b = #{rec['b']}"
      end

      break unless current.has_more && current.resultset_handle

      current = next_page(current.resultset_handle)
      raise "Next page call failed: #{current.message}" unless current.result
    end

    puts "========================================================"
    puts "Executing select from table (DB format)"
    puts "========================================================"
    r = execute_sql(db_path, nil, 'select a, b from t1', nil, data_format: 'DB', include_metadata: true)
    puts "result: #{r.result}, message: #{r.message}"

    if r.column_metadata
      puts r.column_metadata.map { |c| c['label'] }.join("\t")
    end
    current = r
    loop do
      current.result_set.each do |row|
        puts row.map { |v| v.nil? ? 'null' : v.to_s }.join("\t")
      end

      break unless current.has_more && current.resultset_handle

      current = next_page(current.resultset_handle, nil, data_format: 'DB')
      raise "Next page call failed: #{current.message}" unless current.result
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
