// C++ mirror of `synclite_duckdb_store.rs` / `synclite_duckdb_store.py`.
//
// DUCKDB_STORE device: bulk-friendly variant of the DuckDB sample. Same
// DuckDB-backed `synclite::DuckConnection` API; only the `device_type`
// passed to `initialize` differs.

#include "synclite.hpp"

#include <cstdio>
#include <iostream>

namespace sl = synclite;

static const char* DB_PATH     = "sample_duckdb_store.db";
static const char* DEVICE_NAME = "sampledevicestore";

static void print_row(const sl::Row& row) {
    std::cout << "(";
    for (std::size_t i = 0; i < row.size(); ++i) {
        const sl::Value& v = row[i];
        if (i) std::cout << ", ";
        if      (v.is_null()) std::cout << "NULL";
        else if (v.is_int())  std::cout << v.as_int();
        else if (v.is_real()) std::cout << v.as_real();
        else if (v.is_text()) std::cout << "'" << v.as_text() << "'";
        else                  std::cout << "<blob:" << v.as_blob().size() << ">";
    }
    std::cout << ")\n";
}

int main() {
    try {
        sl::initialize("DUCKDB_STORE", DEVICE_NAME, DB_PATH);

        auto conn = sl::DuckConnection::open(DB_PATH);

        conn.execute("DROP TABLE IF EXISTS users");
        conn.execute(
            "CREATE TABLE IF NOT EXISTS users("
            " id INTEGER PRIMARY KEY, name TEXT, score INTEGER)");

        {
            auto stmt = conn.prepare("INSERT INTO users(id, name, score) VALUES(?, ?, ?)");
            stmt.execute({1, "Alice", 100});
            stmt.execute({2, "Bob",   200});
        }

        conn.execute("UPDATE users SET score = ? WHERE name = ?", {250, "Bob"});
        conn.execute("DELETE FROM users WHERE id = ?", {2});

        for (auto& row : conn.query("SELECT id, name, score FROM users ORDER BY id")) {
            print_row(row);
        }

        conn.flush();
        sl::await_sync(DB_PATH, 30.0);
        conn.close();
        return 0;
    } catch (const std::exception& e) {
        std::fprintf(stderr, "ERROR: %s\n", e.what());
        return 1;
    }
}
