// C++ mirror of `synclite_rusqlite_store.rs` / `synclite_rusqlite_store.py`.
//
// STORE-device sample. The runtime is the system of record, so we open
// the connection from a self-contained config file that carries
// `device-type=SQLITE_STORE`.

#include "synclite.hpp"

#include <cstdio>
#include <fstream>
#include <iostream>

namespace sl = synclite;

static const char* DB_PATH     = "sample_rusqlite_store_sqlite.db";
static const char* DEVICE_NAME = "sampledevice";
static const char* CONF_PATH   = "sample_rusqlite_store.conf";

static void write_conf() {
    std::ofstream f(CONF_PATH);
    f << "device-name=sample-rusqlite-store\n"
      << "db-engine=SQLITE\n"
      << "device-type=SQLITE_STORE\n"
      << "db-path=" << DB_PATH << "\n"
      << "local-data-stage-directory=synclite-stage\n";
}

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
        write_conf();

        sl::initialize("SQLITE_STORE", DEVICE_NAME, DB_PATH,
                       std::nullopt, std::string(CONF_PATH));

        auto conn = sl::Connection::open_with_config(CONF_PATH);

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

        conn.close();
        return 0;
    } catch (const std::exception& e) {
        std::fprintf(stderr, "ERROR: %s\n", e.what());
        return 1;
    }
}
