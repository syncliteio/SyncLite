package io.synclite.samples.android

import android.content.Context
import io.synclite.AndroidDestination
import io.synclite.AndroidDeviceOptions
import io.synclite.SyncLiteAndroid
import io.synclite.SyncLiteConnection

/**
 * Android/Kotlin equivalent of the Python core SQLite-to-PostgreSQL sample.
 * Call from a coroutine or a background executor: awaitSync performs blocking I/O.
 */
object SyncLiteAndroidSample {
    // 10.0.2.2 is the Android emulator alias for its host machine.
    private const val POSTGRES_URL =
        "postgresql://postgres:postgres@10.0.2.2:5432/syncdb"

    fun run(context: Context) {
        val dbPath = context.filesDir.resolve("sampledevice.db").path

        SyncLiteAndroid.initialize(
            AndroidDeviceOptions(
                deviceName = "sampledevice",
                databasePath = dbPath,
                destination = AndroidDestination(
                    type = "POSTGRES",
                    connectionString = POSTGRES_URL,
                    database = "syncdb",
                    schema = "syncschema",
                    syncMode = "REPLICATION"
                )
            )
        )

        val connection = SyncLiteConnection.open(dbPath)
        try {
            usersFlow(connection)
            productsFlow(connection)
            ordersFlow(connection)

            // Publish the active segment before the optional demonstration wait.
            connection.flush()
            SyncLiteAndroid.awaitSync(dbPath, 30_000)
            println("[SYNC] awaitSync succeeded")
        } finally {
            connection.close()
        }
    }

    private fun usersFlow(connection: SyncLiteConnection) {
        connection.execute("DROP TABLE IF EXISTS users")
        connection.execute("CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, score INTEGER)")

        connection.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)").apply {
            execute(listOf(1L, "Alice", 100L))
            execute(listOf(2L, "Bob", 200L))
            addBatch(listOf(3L, "Carol", 300L))
            addBatch(listOf(4L, "Dave", 400L))
            executeBatch()
        }
        connection.execute("UPDATE users SET score = ? WHERE name = ?", listOf(250L, "Bob"))
        connection.commit()

        val localUsers = connection.query("SELECT id, name, score FROM users ORDER BY id")
        check(localUsers.size == 4)
    }

    private fun productsFlow(connection: SyncLiteConnection) {
        connection.execute("DROP TABLE IF EXISTS products")
        connection.execute("CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT, price REAL)")
        connection.execute("INSERT INTO products VALUES(?, ?, ?)", listOf(1L, "Widget", 9.99))
        connection.execute("ALTER TABLE products ADD COLUMN tag TEXT")
        connection.execute("INSERT INTO products VALUES(?, ?, ?, ?)", listOf(2L, "Gadget", 19.99, "new"))
        connection.execute("ALTER TABLE products RENAME COLUMN price TO unit_price")
        connection.execute("ALTER TABLE products DROP COLUMN tag")
        connection.commit()
    }

    private fun ordersFlow(connection: SyncLiteConnection) {
        connection.execute("DROP TABLE IF EXISTS orders_archive")
        connection.execute("DROP TABLE IF EXISTS orders")
        connection.execute("CREATE TABLE orders(id INTEGER PRIMARY KEY, product_id INTEGER, qty INTEGER)")
        connection.execute("INSERT INTO orders VALUES(?, ?, ?)", listOf(1L, 1L, 5L))
        connection.execute("INSERT INTO orders VALUES(?, ?, ?)", listOf(2L, 2L, 3L))
        connection.execute("ALTER TABLE orders RENAME TO orders_archive")
        connection.execute("INSERT INTO orders_archive VALUES(?, ?, ?)", listOf(3L, 3L, 7L))
        connection.commit()
    }
}
