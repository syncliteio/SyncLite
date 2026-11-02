package io.synclite.samples.android.awsrds

import android.content.Context
import android.util.Log
import io.synclite.AndroidDestination
import io.synclite.AndroidDeviceOptions
import io.synclite.SyncLiteAndroid
import io.synclite.SyncLiteConnection

/**
 * Replicates a local SQLite database on Android to an AWS RDS PostgreSQL
 * instance over TLS, verifying the server certificate against the AWS RDS CA.
 */
object AwsRdsSyncLiteSample {
    // Replace these placeholders. Never commit real credentials.
    private const val HOST = "your-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
    private const val PORT = 5432
    private const val DATABASE = "syncdb"
    private const val USER = "your_user"
    private const val PASSWORD = "your_password"

    fun run(context: Context) {
        val connectionString = AwsRdsTlsHelper.buildVerifiedConnectionString(
            context = context,
            host = HOST,
            port = PORT,
            database = DATABASE,
            user = USER,
            password = PASSWORD,
        )
        val dbPath = context.filesDir.resolve("awsrds.db").absolutePath

        SyncLiteAndroid.initialize(
            AndroidDeviceOptions(
                deviceName = "awsrds",
                databasePath = dbPath,
                destination = AndroidDestination(
                    type = "POSTGRES",
                    connectionString = connectionString,
                    database = DATABASE,
                    schema = "syncschema",
                    syncMode = "REPLICATION",
                ),
            )
        )

        SyncLiteConnection.open(dbPath).use { connection ->
            connection.execute("DROP TABLE IF EXISTS users")
            connection.execute(
                "CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)"
            )
            connection.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)").apply {
                addBatch(listOf(1L, "Alice", 100L))
                addBatch(listOf(2L, "Bob", 200L))
                executeBatch()
            }
            connection.commit()
            connection.flush()
        }

        SyncLiteAndroid.awaitSync(dbPath, 30_000)
        Log.i("AwsRdsSyncLiteSample", "AWS RDS sync completed; sample returned")
    }
}
