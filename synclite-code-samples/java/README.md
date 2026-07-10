# SyncLite Java sample

[`SyncliteSqlitePostgresApp.java`](SyncliteSqlitePostgresApp.java) — local SQLite app whose every change is replicated to PostgreSQL by the in-process consolidator. Pure JVM — the bundled jar already includes the PostgreSQL JDBC driver, so no extra dependencies are needed on the classpath.

Top-of-file comments inside `appStartup()` show how to:

- swap **device type** (SQLite → Derby / DuckDB / H2 / HyperSQL),
- swap **destination** (Postgres → SQLite / DuckDB),
- flip **sync mode** (`REPLICATION` ↔ `CONSOLIDATION` — see [../README.md § Sync modes](../README.md#sync-modes-replication-vs-consolidation)),
- run in **pure-logger mode** (no inline destination — pair with a standalone Consolidator service).

## Quickest start — add the Maven dependency

**Maven** (`pom.xml`):

```xml
<dependency>
    <groupId>io.synclite</groupId>
    <artifactId>synclite</artifactId>
    <version>1.0.0</version>
</dependency>
```

**Gradle** (`build.gradle`):

```groovy
implementation 'io.synclite:synclite:1.0.0'
```

The published `synclite` jar is self-contained — it bundles the PostgreSQL JDBC driver **and** the platform `synclite_jni` native libraries (Windows x64, Linux x86_64 / aarch64), so no extra classpath entries or native installs are needed. Then jump to [step 1](#1-pre-create-the-postgres-database--schema-one-time) to create the Postgres DB and run the sample.

Prefer to run entirely offline from an extracted release zip? Use [Run from the release zip](#run-from-the-release-zip) below instead.

## Run from the release zip

You are already in `sample-apps/java/` of an extracted release. The release ships the runtime jar under [`../../lib/java/synclite-1.0.0.jar`](../../lib/java/synclite-1.0.0.jar).

### 1. Pre-create the Postgres database + schema (one-time)

```sql
CREATE DATABASE syncdb;
\c syncdb
CREATE SCHEMA syncschema;
```

Defaults: `jdbc:postgresql://localhost:5432/syncdb`, user/password `postgres`/`postgres`, schema `syncschema`. Edit the constants at the top of the `.java` to override.

### 2. Compile + run

**Windows (cmd.exe / PowerShell):**

```bat
javac -cp ..\..\lib\java\synclite-1.0.0.jar SyncliteSqlitePostgresApp.java
java  -cp ..\..\lib\java\synclite-1.0.0.jar;. SyncliteSqlitePostgresApp
```

**Linux / macOS:**

```bash
javac -cp ../../lib/java/synclite-1.0.0.jar SyncliteSqlitePostgresApp.java
java  -cp ../../lib/java/synclite-1.0.0.jar:. SyncliteSqlitePostgresApp
```

(Classpath separator: `;` on Windows, `:` on Linux / macOS.)

Safe to rerun — each table is `DROP TABLE IF EXISTS`'d before being recreated.

## What you'll see

Three flows executed locally on SQLite, each step printing a `[LOCAL ...]` banner:

1. **users** — `INSERT` / `UPDATE` / batched `INSERT`.
2. **products** — `ALTER TABLE ADD / RENAME / DROP COLUMN`.
3. **orders → orders_archive** — `ALTER TABLE RENAME TO`.

Then `SyncLite.awaitSync` blocks until the in-process shipper + consolidator have drained to Postgres, and a `[POSTGRES …]` block reconnects with plain JDBC and prints the same rows + same schema from the destination.

## Troubleshooting

- **`FATAL: database "syncdb" does not exist`** — run the `CREATE DATABASE` / `CREATE SCHEMA` block above.
- **`password authentication failed`** — edit `POSTGRES_USER` / `POSTGRES_PASSWORD` at the top of the sample.
- **Nothing landed on Postgres** — check the trace files documented in [../README.md § Where do the samples write files?](../README.md#where-do-the-samples-write-files).

---

## Developing against the repo

If you're working from a `synclite` repo checkout instead of an extracted release, build the jar from source first:

```bat
mvn -pl :synclite-logger -am -DskipTests package
```

That produces `synclite-logger-java\logger\target\synclite-1.0.0.jar`. Substitute that path for `..\..\lib\java\synclite-1.0.0.jar` in step 2 above.
