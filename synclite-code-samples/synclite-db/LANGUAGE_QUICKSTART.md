# SyncLite DB Samples: Run Guide

This guide shows how to run each language sample in this folder.

## 1) Start SyncLite DB server

In final deployment (recommended), run from the installed SyncLite distribution folder:

- Windows: `synclite-platform-<version>/tools/synclite-db/synclite-db.bat --config synclite_db.conf`
- Linux/macOS: `synclite-platform-<version>/tools/synclite-db/synclite-db.sh --config synclite_db.conf`

For local development from this source repository, run:

- Windows: `db/target/synclite-db.bat --config db/target/synclite_db.conf`
- Linux/macOS: `db/target/synclite-db.sh --config db/target/synclite_db.conf`

Default endpoint used by samples: `http://localhost:5555`.

## 2) Auth modes

Samples support these modes:

- No auth: do not set auth environment variables.
- Global token auth: set `SYNCLITE_DB_AUTH_TOKEN`.
- App auth (HMAC): each request sends `X-SyncLite-App-Id`, `X-SyncLite-Timestamp`, `X-SyncLite-Nonce`, and `X-SyncLite-Signature`.

Important: environment variables are only a simple sample mechanism. They are process-wide, so they do not scale for many tenants/apps sharing one process.

## 2.1) Multi-app production pattern (recommended)

Use per-request app credentials, not process-level env vars.

1. SyncLite DB server config contains all authorized app IDs and secrets:

```properties
enable-app-auth=true
authorized-apps=appA,appB,appC
app.appa.secret=<secret-for-appA>
app.appb.secret=<secret-for-appB>
app.appc.secret=<secret-for-appC>
app.appa.allowed-ops=initialize,begin,commit,rollback,select,next,execute,close
app.appb.allowed-ops=select,next,execute
app.appc.allowed-ops=select,next
```

2. Your service (or gateway) picks the caller app ID for each request.
3. It loads that app's secret from a secure store (Vault/KMS/KeyVault/Secrets Manager).
4. It signs the outgoing JSON payload and sets the `X-SyncLite-*` headers for that request only.

This allows thousands of app IDs behind one service instance, because app ID and secret selection happens per request.

## 2.1.1) Optional protocol-version in requests

You can include `protocol-version` in request JSON.

- If omitted, server defaults to version `1`.
- Supported values: `1` and `1.0`.

Example:

```json
{
	"protocol-version": "1",
	"db-path": "C:\\synclite\\users\\bob\\synclite\\job1\\test.db",
	"sql": "select 1"
}
```

## 2.2) Demo environment variables

The samples in this folder use env vars only to keep the examples small.

### Windows PowerShell examples

No auth:

```powershell
Remove-Item Env:SYNCLITE_DB_AUTH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:SYNCLITE_DB_APP_ID -ErrorAction SilentlyContinue
Remove-Item Env:SYNCLITE_DB_APP_SECRET -ErrorAction SilentlyContinue
```

Global token auth:

```powershell
$env:SYNCLITE_DB_AUTH_TOKEN = "your-token"
```

App auth:

```powershell
$env:SYNCLITE_DB_APP_ID = "sample-app"
$env:SYNCLITE_DB_APP_SECRET = "replace-with-app-secret"
```

For real multi-app systems, do not use a single fixed `SYNCLITE_DB_APP_ID`/`SYNCLITE_DB_APP_SECRET` in a long-running process.

## 3) Run each sample

Run commands from each language folder under `sdk-source`.

### Java

```powershell
cd java
javac -cp . SyncLiteDBClient.java
java -cp . sampleapp.SyncLiteDBClient
```

### Python

```powershell
cd python
python SyncLiteDBClient.py
```

### Node.js

```powershell
cd node.js
npm install axios
node SyncLiteDBClient.js
```

### Go

```powershell
cd go
go run SyncLiteDBClient.go
```

### C#

```powershell
cd c#
dotnet new console -n SyncLiteDBSample -f net8.0
cd SyncLiteDBSample
# Copy SyncLiteDBClient.cs into this project, then add package:
dotnet add package Newtonsoft.Json
# Replace Program.cs content with SyncLiteDBClient.cs content or invoke from Program.cs
dotnet run
```

### Ruby

```powershell
cd ruby
ruby SyncLiteDBClient.rb
```

### Rust

```powershell
cd rust
cargo run
```

### C++

```powershell
cd cpp
# Build with libcurl and OpenSSL available on your system.
# Example (toolchain-dependent):
# g++ -std=c++17 SyncLiteDBClient.cpp -lcurl -lssl -lcrypto -o SyncLiteDBClient
./SyncLiteDBClient
```

## 4) Pagination behavior used by all samples

For large SELECT responses, server may return:

- resultset
- resultset-handle
- has-more

When has-more is true, call next with request-type=next and resultset-handle until has-more becomes false.

Request shape:

```json
{
	"request-type": "next",
	"resultset-handle": "<handle-from-select-or-prior-next>",
	"resultset-pagination-size": 1000
}
```

## 5) C++ app-auth note

The C++ sample computes app-auth headers from:

- `SYNCLITE_DB_APP_ID`
- `SYNCLITE_DB_APP_SECRET`

For compatibility, you can still provide precomputed headers explicitly:

- `SYNCLITE_DB_APP_TIMESTAMP`
- `SYNCLITE_DB_APP_NONCE`
- `SYNCLITE_DB_APP_SIGNATURE`

When both approaches are present, the sample prefers dynamic signature generation from app secret.
