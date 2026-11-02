package io.synclite.samples.android.awsrds

import android.content.Context
import java.io.File

/**
 * Builds a PostgreSQL connection string for an AWS RDS endpoint.
 *
 * The SyncLite PostgreSQL connector runs natively (Rust, rustls) and verifies the
 * server certificate chain and hostname itself. It reads the CA bundle from a
 * filesystem path given as `sslrootcert`, so this helper only copies the AWS RDS
 * CA PEM from `assets/aws-rds-ca.pem` into the app's private files directory and
 * returns a connection string that points at it. A Java `SSLContext` or
 * `TrustManager` is not involved and is not needed.
 */
object AwsRdsTlsHelper {
    const val ASSET_NAME = "aws-rds-ca.pem"

    /** Copies the CA bundle from app assets to `filesDir` and returns the file. */
    fun copyAwsRdsCaToFiles(context: Context): File {
        val target = File(context.filesDir, ASSET_NAME)
        val input = try {
            context.assets.open(ASSET_NAME)
        } catch (e: java.io.FileNotFoundException) {
            throw IllegalStateException(
                "Missing assets/$ASSET_NAME. Download the AWS RDS CA bundle for your " +
                    "region and place it at app/src/main/assets/$ASSET_NAME",
                e,
            )
        }
        input.use { source -> target.outputStream().use { sink -> source.copyTo(sink) } }
        return target
    }

    /** Returns a libpq key/value connection string with `sslmode=verify-full`. */
    fun buildVerifiedConnectionString(
        context: Context,
        host: String,
        port: Int,
        database: String,
        user: String,
        password: String,
    ): String {
        val caPath = copyAwsRdsCaToFiles(context).absolutePath
        return listOf(
            "host" to host,
            "port" to port.toString(),
            "dbname" to database,
            "user" to user,
            "password" to password,
            "sslmode" to "verify-full",
            "sslrootcert" to caPath,
        ).joinToString(" ") { (key, value) -> "$key=${quote(value)}" }
    }

    /** Single-quotes a libpq value, escaping backslashes and quotes. */
    private fun quote(value: String): String =
        "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"
}
