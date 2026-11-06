# SyncLite Kotlin/Android sample

[SyncLiteAndroidSample.kt](SyncLiteAndroidSample.kt) runs a local SQLite
database on Android and replicates every data and schema change to PostgreSQL.
It demonstrates device initialization, direct and prepared statements, batch
writes, transactions, schema evolution, local queries, `flush()`, and
`awaitSync()`.

This sample runs on Android, not as a desktop JVM program. For local
development, use an Android `x86_64` emulator. `10.0.2.2` is the emulator's
alias for its host machine, so the checked-in sample can reach PostgreSQL
running on the host without a source change.

## Prerequisites

- Android Studio with JDK 17.
- Android SDK API 35 and Android SDK Build-Tools 35.
- An Android app with `minSdkVersion` 26 or newer. The native CDC sidecar requires Android API 26+; lower API levels are unsupported.
- An API 26 or newer `x86_64` Android emulator. API 35 is recommended.
- PostgreSQL reachable from the emulator, or Docker Desktop to start the
	disposable PostgreSQL container shown below.
- Either access to Maven Central for `io.synclite:synclite-android:1.2.0`,
  or an extracted release containing `lib/android/synclite-android-1.2.0.aar`.

Both the Maven-published and release-bundled AARs are prebuilt. Running this sample does not require Rust, Cargo,
the Android NDK, CMake, Cargo NDK, or a SyncLite source build.

## 1. Start PostgreSQL on the host

If PostgreSQL is already installed, create database `syncdb`, ensure port
5432 accepts connections from the emulator, and use a valid username and
password in the sample.

The quickest isolated setup is Docker Desktop:

```powershell
docker run --name synclite-postgres `
	-e POSTGRES_USER=postgres `
	-e POSTGRES_PASSWORD=postgres `
	-e POSTGRES_DB=syncdb `
	-p 5432:5432 `
	-d postgres:16

docker exec synclite-postgres `
	psql -U postgres -d syncdb `
	-c "CREATE SCHEMA IF NOT EXISTS syncschema;"
```

The checked-in sample uses:

```text
postgresql://postgres:postgres@10.0.2.2:5432/syncdb
```

If port 5432 is already occupied, stop the existing service or use that
PostgreSQL instance. If Windows Firewall prompts for Docker or PostgreSQL
network access, allow access for the applicable private network.

## 2. Create and start the Android emulator

1. Open Android Studio.
2. Select **Tools > Device Manager**.
3. Create a virtual device, such as **Pixel 8**.
4. Select an API 35 **x86_64** system image and finish the wizard.
5. Start the emulator and wait for its home screen.

The SyncLite AAR contains native libraries for `x86_64` emulators and
`arm64-v8a` physical devices. An ARM emulator on an x86-64 host is not the
recommended configuration.

## Run the sample

The following steps wire [SyncLiteAndroidSample.kt](SyncLiteAndroidSample.kt)
into a new Android Studio application. Choose either the published Maven
artifact or the AAR bundled in the platform release.

### 1. Create the application

1. In Android Studio select **New Project > Empty Views Activity**.
2. Set the name to `SyncLiteSample`.
3. Set the package to `io.synclite.samples.android`.
4. Select Kotlin and minimum SDK 26 or newer.
5. Wait for Gradle synchronization to complete.

### 2. Add the SyncLite library

Choose exactly one of the following options; do not add both dependencies.

#### Option A: Published Maven artifact

Ensure the application's `settings.gradle.kts` contains:

```kotlin
dependencyResolutionManagement {
	repositories {
		google()
		mavenCentral()
	}
}
```

Add this dependency to the application's `app/build.gradle.kts`:

```kotlin
dependencies {
		implementation("io.synclite:synclite-android:1.2.0")
}
```

Click **Sync Project with Gradle Files**.

The `1.2.0` AAR must be published to Maven Central first. If Gradle cannot
resolve it, check release availability and repository access; do not switch
to the desktop Java artifact or copy unrelated native libraries into the app.

#### Option B: Bundled release AAR

Create an `app/libs` directory in the new project. Copy
`lib/android/synclite-android-1.2.0.aar` from the extracted release into it,
then use this dependency instead of Option A:

```kotlin
dependencies {
	implementation(files("libs/synclite-android-1.2.0.aar"))
}
```

Click **Sync Project with Gradle Files**. This option does not require the
SyncLite artifact to have been published to Maven Central; normal Android
project dependencies still use their configured repositories.

### 3. Add and invoke the sample

Copy `SyncLiteAndroidSample.kt` into:

```text
app/src/main/java/io/synclite/samples/android/SyncLiteAndroidSample.kt
```

In the generated `MainActivity`, invoke it from a worker thread. Do not run it
on the Android main thread because `awaitSync()` performs blocking I/O:

```kotlin
import java.util.concurrent.Executors

private val syncLiteWorker = Executors.newSingleThreadExecutor()

// Call this from a button handler or from onCreate while testing.
syncLiteWorker.execute {
		SyncLiteAndroidSample.run(applicationContext)
}
```

Add internet access immediately inside the root `manifest` element in
`app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Select the running emulator and click **Run**. Open **Logcat**, filter by the
application package, and wait for:

```text
[SYNC] awaitSync succeeded
```

## What the sample does

The local database is stored in the application's private files directory as
`sampledevice.db`. The sample safely recreates and exercises three flows:
 
SyncLite stores staging and consolidator work state beneath the database's
parent directory, at `synclite/job1/stageDir` and `synclite/job1/workDir`.
These directories stay inside app-private files storage; no external-storage
permission is required. Do not place durable sync state in `cacheDir`.

1. `users` — direct inserts, prepared and batched inserts, and an update.
2. `products` — add, rename, and remove a column.
3. `orders` → `orders_archive` — rename a table and continue writing to it.

After committing the local changes, the sample calls `flush()` to publish the
active log segment and `awaitSync()` to wait up to 30 seconds for destination
apply to complete. It closes the local connection only after that wait
completes.

## Verify PostgreSQL

With the Docker container still running:

```powershell
docker exec synclite-postgres `
	psql -U postgres -d syncdb `
	-c "SELECT * FROM syncschema.users ORDER BY id;"
```

The result should contain Alice, Bob, Carol, and Dave. Bob's score should be
250.

## Troubleshooting

- **`nativeInitialize`: read-only filesystem (OS error 30)** — use the updated
	AAR with Android app-private stage/work defaults, and supply an absolute
	`databasePath` under `context.filesDir`. Older AARs used desktop home/CWD
	defaults, which are not writable on Android. Rebuild/reinstall the app with
	the corrected AAR; no root access or external-storage permission is needed.
- **`Connection refused` or `awaitSync` times out** — verify PostgreSQL is
	running, port 5432 is published, and the emulator URL uses `10.0.2.2`, not
	`localhost`.
- **`password authentication failed`** — update `POSTGRES_URL` near the top of
	the sample to match the server credentials.
- **`database "syncdb" does not exist`** — create `syncdb` before running the
	application.
- **No matching native library / ABI error** — use an `x86_64` emulator or an
	`arm64-v8a` physical device.
- **The app freezes** — ensure `SyncLiteAndroidSample.run(context)` is invoked
	from a coroutine using `Dispatchers.IO` or from an executor, never directly
	from the main thread.
- **Rerunning after a failed attempt gives stale state** — uninstall the sample
	app from the emulator to remove its private database, then run it again.
