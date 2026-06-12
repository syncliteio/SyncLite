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

        // PostgreSQL destination (default). Comment out and uncomment one
        // of the alternatives below for SQLite / DuckDB destinations, or
        // for the no-inline-destination path that pairs with a
        // centralized Consolidator service.
        sl::DestinationOptions dst;
        dst.dst_type              = "POSTGRES";
        dst.dst_connection_string = "postgresql://postgres:postgres@localhost:5432/syncdb";
        dst.dst_database          = "syncdb";
        dst.dst_schema            = "syncschema";
        dst.dst_sync_mode         = "CONSOLIDATION";

        sl::initialize("STREAMING", DEVICE_NAME, DB_PATH, dst);

        // SQLite destination example:
        // sl::DestinationOptions dst;
        // dst.dst_type              = "SQLITE";
        // dst.dst_connection_string = "dst_sqlite.db";
        // sl::initialize("STREAMING", DEVICE_NAME, DB_PATH, dst);

        // DuckDB destination example:
        // sl::DestinationOptions dst;
        // dst.dst_type              = "DUCKDB";
        // dst.dst_connection_string = "dst_duckdb.duckdb";
        // dst.dst_database          = "dst_duckdb";
        // dst.dst_schema            = "main";
        // sl::initialize("STREAMING", DEVICE_NAME, DB_PATH, dst);

        // Centralized Consolidator path — no inline destination. The
        // device only logs locally; a separate standalone Consolidator
        // service reads the log segments from staging storage and
        // applies them to the configured destination(s):
        // sl::initialize("STREAMING", DEVICE_NAME, DB_PATH,
        //                std::nullopt, std::string(CONF_PATH));

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

        // Force the active log segment to roll, then block until the
        // in-process shipper + consolidator have fully applied it to
        // PostgreSQL. Short-lived programs would otherwise exit before
        // the background pipeline gets to drain.
        conn.flush();
        sl::await_sync(DB_PATH, 30.0);
        conn.close();
        return 0;
    } catch (const std::exception& e) {
        std::fprintf(stderr, "ERROR: %s\n", e.what());
        return 1;
    }
}
