// C++ mirror of `synclite_streaming.rs` / `synclite_streaming.py`.
//
// STREAMING-device sample. Same Connection API; only `device-type` differs.

#include "synclite.hpp"

#include <cstdio>
#include <cstdint>
#include <fstream>
#include <string>

namespace sl = synclite;

static const char* DB_PATH     = "sample_streaming_sqlite.db";
static const char* DEVICE_NAME = "sampledevice";
static const char* CONF_PATH   = "sample_streaming.conf";

static void write_conf() {
    std::ofstream f(CONF_PATH);
    f << "device-name=sample-streaming\n"
      << "db-engine=SQLITE\n"
      << "device-type=STREAMING\n"
      << "db-path=" << DB_PATH << "\n"
      << "local-data-stage-directory=synclite-stage\n";
}

int main() {
    try {
        write_conf();

        sl::initialize("STREAMING", DEVICE_NAME, DB_PATH,
                       std::nullopt, std::string(CONF_PATH));

        auto conn = sl::Connection::open_with_config(CONF_PATH);

        conn.execute(
            "CREATE TABLE IF NOT EXISTS events("
            "  ts BIGINT, event_type TEXT, payload TEXT)");

        {
            auto stmt = conn.prepare("INSERT INTO events(ts, event_type, payload) VALUES(?, ?, ?)");
            stmt.execute({std::int64_t(1714200000000LL), "SIGNUP", "{\"user\":\"alice\"}"});
            stmt.execute({std::int64_t(1714200001000LL), "LOGIN",  "{\"user\":\"alice\"}"});
        }

        {
            auto stmt = conn.prepare("INSERT INTO events(ts, event_type, payload) VALUES(?, ?, ?)");
            for (int i = 0; i < 10; ++i) {
                std::string payload = "{\"i\":" + std::to_string(i) + "}";
                stmt.add_batch({std::int64_t(1714200002000LL + i), "HEARTBEAT", payload});
            }
            stmt.execute_batch();
        }

        conn.close();
        return 0;
    } catch (const std::exception& e) {
        std::fprintf(stderr, "ERROR: %s\n", e.what());
        return 1;
    }
}
