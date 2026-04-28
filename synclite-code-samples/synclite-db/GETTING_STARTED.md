These are reference client samples intended to show API usage patterns. For language-specific run commands, see `LANGUAGE_QUICKSTART.md` in this folder.

1. Go to the directory `synclite-platform-<version>\tools\synclite-db`.

2. Check the configuration values in `synclite_db.conf`.

3. Start the server:

```bash
synclite-db.bat --config synclite_db.conf
# or
synclite-db.sh --config synclite_db.conf
```

4. Use any sample client in this directory to execute the core APIs:

- `initializeDB`
- `beginTransaction`
- `commitTransaction`
- `rollbackTransaction`
- `executeSQL`
- `next` (page through a large result set using `resultset-handle`)
- `closeDB`

5. Basic JSON workflow example.

- Initialize device

```json
{
  "db-type": "SQLITE",
  "db-path": "C:\\synclite\\users\\bob\\synclite\\job1\\test.db",
  "synclite-logger-config": "C:\\synclite\\users\\bob\\synclite\\job1\\synclite_logger.conf",
  "sql": "initialize"
}
```

- Create table

```json
{
  "db-path": "C:\\synclite\\users\\bob\\synclite\\job1\\test.db",
  "sql": "CREATE TABLE IF NOT EXISTS t1(a INT, b INT)"
}
```

- Batched insert

```json
{
  "db-path": "C:\\synclite\\users\\bob\\synclite\\job1\\test.db",
  "sql": "INSERT INTO t1(a,b) VALUES(?, ?)",
  "arguments": [[1, "one"], [2, "two"]]
}
```

- Begin transaction

```json
{
  "db-path": "C:\\synclite\\users\\bob\\synclite\\job1\\test.db",
  "sql": "begin"
}
```

- Execute SQL inside transaction

```json
{
  "db-path": "C:\\synclite\\users\\bob\\synclite\\job1\\test.db",
  "sql": "INSERT INTO t1(a,b) VALUES(?, ?)",
  "txn-handle": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "arguments": [[3, "three"], [4, "four"]]
}
```

- Commit transaction

```json
{
  "db-path": "C:\\synclite\\users\\bob\\synclite\\job1\\test.db",
  "txn-handle": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "sql": "commit"
}
```

- Close device

```json
{
  "db-path": "C:\\synclite\\users\\bob\\synclite\\job1\\test.db",
  "sql": "close"
}
```

- Fetch next page of result set

```json
{
  "request-type": "next",
  "resultset-handle": "6d6d3f29-c184-4b2b-98ea-4dca6f698af0",
  "resultset-pagination-size": 1000
}
```

When a `select` response includes `resultset-handle` and `has-more=true`, keep calling `next` until `has-more=false`.

All sample source files in `sdk-source` already demonstrate this by iterating pages with `next`/`next_page` after a SELECT.

6. Security headers support.

- Global token mode: send `X-SyncLite-Token`.
- App auth mode: send all four headers:
  - `X-SyncLite-App-Id`
  - `X-SyncLite-Timestamp`
  - `X-SyncLite-Nonce`
  - `X-SyncLite-Signature`

The samples in this folder now support both modes via environment variables.

7. Environment variables used by samples.

- `SYNCLITE_DB_AUTH_TOKEN`
  - Optional global token value.
- `SYNCLITE_DB_APP_ID`
  - App identifier for per-app auth.
- `SYNCLITE_DB_APP_SECRET`
  - Shared app secret used to compute HMAC signature.

The C++ sample also supports precomputed app-auth headers when needed:

- `SYNCLITE_DB_APP_TIMESTAMP`
- `SYNCLITE_DB_APP_NONCE`
- `SYNCLITE_DB_APP_SIGNATURE`
