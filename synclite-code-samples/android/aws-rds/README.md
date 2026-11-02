# AWS RDS PostgreSQL sample for Android

This sample replicates a local SQLite database on Android to an AWS RDS PostgreSQL instance over TLS, verifying the server certificate against the AWS RDS CA bundle.

## How TLS works here

AWS RDS certificates are signed by the AWS RDS CA, which is not in the default public root store. The SyncLite PostgreSQL connector is native (Rust, rustls) and takes the CA from a **file path** in the connection string:

- `sslmode=verify-full` (or `verify-ca`) turns on TLS. The certificate chain and the hostname are always verified.
- `sslrootcert=<path>` adds your CA bundle to the trusted roots (alongside the built-in public roots).
- Both the key/value form and the `postgresql://` URI form are supported.
- A Java `SSLContext` / `TrustManager` is **not** used by the connector and is not needed.

If the CA file is missing, empty, or contains no PEM certificates, the connector fails with a clear error instead of silently falling back.

> Requires an Android AAR built from a SyncLite version that includes the connector TLS normalization. With an older AAR, connection strings containing `sslrootcert` or `verify-*` are rejected with `invalid PostgreSQL connection configuration`. Rebuild and re-add the AAR if you see that error.

## Files in this folder

- `AwsRdsTlsHelper.kt` - copies the AWS RDS CA PEM from app assets into the app's private files directory and builds the connection string.
- `AwsRdsSyncLiteSample.kt` - a minimal SyncLite Android sample pointed at an Amazon RDS PostgreSQL endpoint.

## Setup steps

### 1. Download the AWS RDS CA bundle

Download the CA bundle for your region (or the global bundle) from the AWS RDS documentation and save it as:

```text
app/src/main/assets/aws-rds-ca.pem
```

It must contain one or more PEM certificates (`-----BEGIN CERTIFICATE-----`).

### 2. Update the connection settings

Edit `AwsRdsSyncLiteSample.kt`:

```kotlin
private const val HOST = "your-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
private const val DATABASE = "syncdb"
private const val USER = "your_user"
private const val PASSWORD = "your_password"
```

Use the exact RDS endpoint hostname; `verify-full` checks it against the certificate.

### 3. Connection string produced by the helper

```text
host='your-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com' port='5432' dbname='syncdb' user='your_user' password='your_password' sslmode='verify-full' sslrootcert='/data/user/0/com.example.app/files/aws-rds-ca.pem'
```

The equivalent URI form also works:

```text
postgresql://user:password@your-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com:5432/syncdb?sslmode=verify-full&sslrootcert=/data/user/0/com.example.app/files/aws-rds-ca.pem
```

### 4. Call the sample from your app

Run it off the main thread:

```kotlin
AwsRdsSyncLiteSample.run(context)
```

`awaitSync(dbPath, 30_000)` returns as soon as all committed writes are applied;
30 seconds is the maximum wait, not a delay before closing the app. If sync
does not complete within that budget, the call throws a native exception.
Handle that exception in your background task and report the failure to the UI.
The sample logs `AWS RDS sync completed; sample returned` after a successful wait.

Returning from the sample does not finish your Activity or stop the background
consolidator. If this is a one-shot demo, have the owning Activity call `finish()`
on the UI thread after its background task completes. Do not use `System.exit`
to terminate the Android process.

At the default INFO trace level, lifecycle and replication results remain
visible. Detailed `[sequence]` polling, mirroring and already-applied messages
are DEBUG-only; enable DEBUG only while diagnosing a problem.

## Test connectivity first

Before running the sample, confirm the RDS endpoint is reachable from the same network as the device or emulator.

1. Check the TCP connection to the endpoint on port 5432.

   Windows (PowerShell):

   ```powershell
   Test-NetConnection your-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com -Port 5432
   ```

   Linux / macOS:

   ```bash
   nc -zv your-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com 5432
   ```

2. Read the result.

   | Result | Meaning |
   | --- | --- |
   | `TcpTestSucceeded : True` | The network path is open. Continue with the sample. |
   | `TcpTestSucceeded : False` or timeout | The security group, public accessibility or routing blocks the connection. Fix this before using SyncLite. |
   | Name resolution fails | The hostname is wrong. Copy the endpoint from the RDS console. |

3. If the check passes from your PC but the app still fails, the device network is the problem (VPN, carrier blocking port 5432, or a different network). Test from a client on the device's network, or switch the device to a network that allows port 5432.

4. Optionally verify credentials and TLS with `psql`:

   ```bash
   psql "host=your-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com port=5432 dbname=syncdb user=your_user sslmode=verify-full sslrootcert=aws-rds-ca.pem"
   ```

Also check that the app manifest declares `<uses-permission android:name="android.permission.INTERNET" />`.

## Important notes

- The device must reach the RDS endpoint (public accessibility, security group inbound rule on port 5432, VPC routing).
- The database named in `DATABASE` must already exist; SyncLite creates the schema and tables.
- Do not use `sslmode=disable` for AWS RDS in production.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `invalid PostgreSQL connection configuration` | The AAR predates the connector fix; rebuild it. |
| `Missing assets/aws-rds-ca.pem` | CA file not in `app/src/main/assets/`. |
| `sslrootcert ... contains no PEM certificates` | The file is not a PEM bundle. |
| `PostgreSQL connection failed (...; SQLSTATE=none); cause: ...` | The failure happened on the device before the server answered. Read the `cause:` text below. |
| `cause: ... timed out` / `Connection refused` / `Network is unreachable` | Security group, public accessibility, VPC routing or device network. Not TLS. |
| `cause: ... failed to lookup address` | Wrong or unreachable hostname. |
| `cause: ... UnknownIssuer` | `aws-rds-ca.pem` is missing the CA for your region (use the regional or global RDS bundle). |
| `cause: ... NotValidForName` | The host in the connection string is not the RDS endpoint name (do not use an IP address). |
| `SQLSTATE=28P01` / `28000` | Wrong user or password, or `pg_hba` rejection. |
| `SQLSTATE=3D000` | The database in `DATABASE` does not exist. |

When the destination is unreachable, `awaitSync` throws when its timeout expires,
while the background consolidator continues retrying. Check
`synclite_device.trace` for the `cause:` line. Rebuild the AAR to include the
TLS-aware checkpoint reader and full network deadline; older builds could apply
data successfully but fail to observe the PostgreSQL checkpoint over TLS.
