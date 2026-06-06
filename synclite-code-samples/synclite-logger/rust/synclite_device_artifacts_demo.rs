use std::fs;
use std::path::{Path, PathBuf};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

use ::duckdb::{params, params_from_iter as duck_params_from_iter, types::Value as RawDuckValue, Connection as RawDuckDbConnection, DropBehavior};
use ::rusqlite::Connection as RawSqliteConnection;
use synclite::duckdb;
use synclite::rusqlite;
use logger_core::record::ArgValue;
use synclite::{DeviceType, Result};

fn main() -> Result<()> {
    let root = demo_root();
    fs::create_dir_all(&root).unwrap();

    println!("Demo root: {}", root.display());

    let bulk_only = std::env::var("SYNCLITE_BULK_ONLY")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false);

    if !bulk_only {
        run_sqlite_demo(&root)?;
        run_duckdb_demo(&root)?;
    }
    run_sqlite_bulk_demo(&root)?;
    run_duckdb_bulk_demo(&root)?;
    run_raw_duckdb_bulk_demo(&root)?;
    run_raw_duckdb_appender_bulk_demo(&root)?;

    Ok(())
}

fn run_sqlite_demo(root: &Path) -> Result<()> {
    let device_name = "sqlitedemorust";
    let db_path = root.join("sqlite_demo.db");
    let conf_path = root.join("sqlite_demo.conf");
    let stage_dir = root.join("stage");

    write_conf(
        &conf_path,
        device_name,
        "sqlite",
        "SQLITE",
        &db_path,
        &stage_dir,
    );

    synclite::initialize(
        DeviceType::Sqlite,
        device_name,
        &db_path,
        None,
        synclite::SyncLiteOptions {
            config_path: Some(conf_path.clone()),
            ..Default::default()
        },
    )?;

    // Destination-aware shape:
    // synclite::initialize(DeviceType::Sqlite, device_name, &db_path, None, synclite::SyncLiteOptions::default())?;

    // PostgreSQL destination example:
    // synclite::initialize(
    //     DeviceType::Sqlite,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Postgres,
    //         dst_connection_string: "postgresql://user:password@localhost:5432/synclite_demo".into(),
    //         dst_database: Some("synclite_demo".into()),
    //         dst_schema: Some("public".into()),
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;

    // SQLite destination example:
    // synclite::initialize(
    //     DeviceType::Sqlite,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Sqlite,
    //         dst_connection_string: "dst_sqlite.db".into(),
    //         dst_database: None,
    //         dst_schema: None,
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;

    // DuckDB destination example:
    // synclite::initialize(
    //     DeviceType::Sqlite,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Duckdb,
    //         dst_connection_string: "dst_duckdb.duckdb".into(),
    //         dst_database: Some("dst_duckdb".into()),
    //         dst_schema: Some("main".into()),
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;
    let mut conn = rusqlite::Connection::open_with_config(&conf_path)?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS t_bulk (id INTEGER PRIMARY KEY, name TEXT)",
        &[],
    )?;

    {
        let mut stmt = conn.prepare("INSERT INTO t_bulk (id, name) VALUES (?, ?)")?;
        for i in 1..=5 {
            stmt.add_batch(&[
                ArgValue::Int(i),
                ArgValue::Text(format!("sqlite-user-{i}")),
            ]);
        }
        stmt.execute_batch()?;
    }

    conn.commit()?;
    conn.close()?;

    print_artifacts("SQLite", root, device_name, &db_path, &stage_dir);
    Ok(())
}

fn run_duckdb_demo(root: &Path) -> Result<()> {
    let device_name = "duckdbdemorust";
    let db_path = root.join("duckdb_demo.duckdb");
    let conf_path = root.join("duckdb_demo.conf");
    let stage_dir = root.join("stage");

    write_conf(
        &conf_path,
        device_name,
        "duckdb",
        "DUCKDB",
        &db_path,
        &stage_dir,
    );

    synclite::initialize(
        DeviceType::DuckDb,
        device_name,
        &db_path,
        None,
        synclite::SyncLiteOptions {
            config_path: Some(conf_path.clone()),
            ..Default::default()
        },
    )?;

    // Destination-aware shape:
    // synclite::initialize(DeviceType::DuckDb, device_name, &db_path, None, synclite::SyncLiteOptions::default())?;

    // PostgreSQL destination example:
    // synclite::initialize(
    //     DeviceType::DuckDb,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Postgres,
    //         dst_connection_string: "postgresql://user:password@localhost:5432/synclite_demo".into(),
    //         dst_database: Some("synclite_demo".into()),
    //         dst_schema: Some("public".into()),
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;

    // SQLite destination example:
    // synclite::initialize(
    //     DeviceType::DuckDb,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Sqlite,
    //         dst_connection_string: "dst_sqlite.db".into(),
    //         dst_database: None,
    //         dst_schema: None,
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;

    // DuckDB destination example:
    // synclite::initialize(
    //     DeviceType::DuckDb,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Duckdb,
    //         dst_connection_string: "dst_duckdb.duckdb".into(),
    //         dst_database: Some("dst_duckdb".into()),
    //         dst_schema: Some("main".into()),
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;
    let mut conn = duckdb::Connection::open_with_config(&conf_path)?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS t_bulk (id INTEGER, name TEXT)",
        &[],
    )?;

    {
        let mut stmt = conn.prepare("INSERT INTO t_bulk (id, name) VALUES (?, ?)")?;
        for i in 1..=5 {
            stmt.add_batch(&[
                ArgValue::Int(i),
                ArgValue::Text(format!("duckdb-user-{i}")),
            ]);
        }
        stmt.execute_batch()?;
    }

    conn.commit()?;
    conn.close()?;

    print_artifacts("DuckDB", root, device_name, &db_path, &stage_dir);
    Ok(())
}

fn run_sqlite_bulk_demo(root: &Path) -> Result<()> {
    let device_name = "sqlitebulkrust";
    let db_path = root.join("sqlite_bulk_1m.db");
    let conf_path = root.join("sqlite_bulk_1m.conf");
    let stage_dir = root.join("stage");

    write_conf(
        &conf_path,
        device_name,
        "sqlite",
        "SQLITE",
        &db_path,
        &stage_dir,
    );

    synclite::initialize(
        DeviceType::Sqlite,
        device_name,
        &db_path,
        None,
        synclite::SyncLiteOptions {
            config_path: Some(conf_path.clone()),
            ..Default::default()
        },
    )?;

    // Destination-aware shape:
    // synclite::initialize(DeviceType::Sqlite, device_name, &db_path, None, synclite::SyncLiteOptions::default())?;

    // PostgreSQL destination example:
    // synclite::initialize(
    //     DeviceType::Sqlite,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Postgres,
    //         dst_connection_string: "postgresql://user:password@localhost:5432/synclite_demo".into(),
    //         dst_database: Some("synclite_demo".into()),
    //         dst_schema: Some("public".into()),
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;

    // SQLite destination example:
    // synclite::initialize(
    //     DeviceType::Sqlite,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Sqlite,
    //         dst_connection_string: "dst_sqlite.db".into(),
    //         dst_database: None,
    //         dst_schema: None,
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;

    // DuckDB destination example:
    // synclite::initialize(
    //     DeviceType::Sqlite,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Duckdb,
    //         dst_connection_string: "dst_duckdb.duckdb".into(),
    //         dst_database: Some("dst_duckdb".into()),
    //         dst_schema: Some("main".into()),
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;
    let mut conn = rusqlite::Connection::open_with_config(&conf_path)?;
    conn.set_auto_commit(false);

    conn.execute(
        "CREATE TABLE IF NOT EXISTS t_bulk_1m (id INTEGER PRIMARY KEY, name TEXT)",
        &[],
    )?;
    conn.commit()?;

    let total_rows = bulk_total_rows();
    let batches = bulk_batches();
    assert_eq!(
        total_rows % batches,
        0,
        "SYNCLITE_TOTAL_ROWS ({total_rows}) must be divisible by SYNCLITE_BATCHES ({batches})"
    );
    let chunk_size = total_rows / batches;
    let started = Instant::now();

    let mut next_id = 1i64;
    let mut chunk_no = 0i64;
    while next_id <= total_rows {
        let end = (next_id + chunk_size - 1).min(total_rows);
        {
            let mut stmt = conn.prepare("INSERT INTO t_bulk_1m (id, name) VALUES (?, ?)")?;
            for id in next_id..=end {
                stmt.add_batch(&[
                    ArgValue::Int(id),
                    ArgValue::Text(format!("sqlite-bulk-{id}")),
                ]);
            }
            stmt.execute_batch()?;
        }
        conn.commit()?;
        chunk_no += 1;
        println!("SQLite bulk progress: batch {chunk_no}/{batches}, inserted {end}/{total_rows}");
        next_id = end + 1;
    }

    let elapsed = started.elapsed();
    conn.close()?;

    let stage_subdir = find_stage_subdir(&stage_dir, device_name)
        .expect("sqlite bulk stage subdir not found");
    let insert_txns = count_distinct_insert_commits(&stage_subdir, "t_bulk_1m");
    assert_eq!(
        insert_txns,
        batches as usize,
        "expected exactly {batches} INSERT transactions (one per batch), found {insert_txns}"
    );

    print_artifacts("SQLite 1M bulk", root, device_name, &db_path, &stage_dir);
    print_stage_stats("SQLite 1M bulk", &stage_dir, device_name);
    println!("SQLite 1M bulk insert transactions: {insert_txns}");
    println!("SQLite 1M bulk elapsed: {:.2?}", elapsed);
    Ok(())
}

fn run_duckdb_bulk_demo(root: &Path) -> Result<()> {
    let device_name = "duckdbbulkrust";
    let db_path = root.join("duckdb_bulk_1m.duckdb");
    let conf_path = root.join("duckdb_bulk_1m.conf");
    let stage_dir = root.join("stage");

    write_conf(
        &conf_path,
        device_name,
        "duckdb",
        "DUCKDB",
        &db_path,
        &stage_dir,
    );

    synclite::initialize(
        DeviceType::DuckDb,
        device_name,
        &db_path,
        None,
        synclite::SyncLiteOptions {
            config_path: Some(conf_path.clone()),
            ..Default::default()
        },
    )?;

    // Destination-aware shape:
    // synclite::initialize(DeviceType::DuckDb, device_name, &db_path, None, synclite::SyncLiteOptions::default())?;

    // PostgreSQL destination example:
    // synclite::initialize(
    //     DeviceType::DuckDb,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Postgres,
    //         dst_connection_string: "postgresql://user:password@localhost:5432/synclite_demo".into(),
    //         dst_database: Some("synclite_demo".into()),
    //         dst_schema: Some("public".into()),
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;

    // SQLite destination example:
    // synclite::initialize(
    //     DeviceType::DuckDb,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Sqlite,
    //         dst_connection_string: "dst_sqlite.db".into(),
    //         dst_database: None,
    //         dst_schema: None,
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;

    // DuckDB destination example:
    // synclite::initialize(
    //     DeviceType::DuckDb,
    //     device_name,
    //     &db_path,
    //     Some(synclite::DestinationOptions {
    //         dst_type: synclite::DstType::Duckdb,
    //         dst_connection_string: "dst_duckdb.duckdb".into(),
    //         dst_database: Some("dst_duckdb".into()),
    //         dst_schema: Some("main".into()),
    //         dst_sync_mode: synclite::DstSyncMode::Consolidation,
    //     }),
    //     synclite::SyncLiteOptions::default(),
    // )?;
    let mut conn = duckdb::Connection::open_with_config(&conf_path)?;
    conn.set_auto_commit(false);

    conn.execute(
        "CREATE TABLE IF NOT EXISTS t_bulk_1m (id INTEGER, name TEXT)",
        &[],
    )?;
    conn.commit()?;

    let total_rows = bulk_total_rows();
    let batches = bulk_batches();
    assert_eq!(
        total_rows % batches,
        0,
        "SYNCLITE_TOTAL_ROWS ({total_rows}) must be divisible by SYNCLITE_BATCHES ({batches})"
    );
    let chunk_size = total_rows / batches;
    let started = Instant::now();

    let mut next_id = 1i64;
    let mut chunk_no = 0i64;
    while next_id <= total_rows {
        let end = (next_id + chunk_size - 1).min(total_rows);
        {
            let mut stmt = conn.prepare("INSERT INTO t_bulk_1m (id, name) VALUES (?, ?)")?;
            for id in next_id..=end {
                stmt.add_batch(&[
                    ArgValue::Int(id),
                    ArgValue::Text(format!("duckdb-bulk-{id}")),
                ]);
            }
            stmt.execute_batch()?;
        }
        conn.commit()?;
        chunk_no += 1;
        println!("DuckDB bulk progress: batch {chunk_no}/{batches}, inserted {end}/{total_rows}");
        next_id = end + 1;
    }

    let elapsed = started.elapsed();
    conn.close()?;

    let stage_subdir = find_stage_subdir(&stage_dir, device_name)
        .expect("duckdb bulk stage subdir not found");
    let insert_txns = count_distinct_insert_commits(&stage_subdir, "t_bulk_1m");
    assert_eq!(
        insert_txns,
        batches as usize,
        "expected exactly {batches} INSERT transactions (one per batch), found {insert_txns}"
    );

    print_artifacts("DuckDB 1M bulk", root, device_name, &db_path, &stage_dir);
    print_stage_stats("DuckDB 1M bulk", &stage_dir, device_name);
    println!("DuckDB 1M bulk insert transactions: {insert_txns}");
    println!("DuckDB 1M bulk elapsed: {:.2?}", elapsed);
    Ok(())
}

fn run_raw_duckdb_bulk_demo(root: &Path) -> Result<()> {
    let db_path = root.join("duckdb_raw_bulk_1m.duckdb");
    let conn = RawDuckDbConnection::open(&db_path).map_err(|e| logger_core::Error::Db(e.to_string()))?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS t_bulk_1m (id INTEGER, name TEXT)",
        [],
    )
    .map_err(|e| logger_core::Error::Db(e.to_string()))?;

    let total_rows = bulk_total_rows();
    let batches = bulk_batches();
    assert_eq!(
        total_rows % batches,
        0,
        "SYNCLITE_TOTAL_ROWS ({total_rows}) must be divisible by SYNCLITE_BATCHES ({batches})"
    );
    let chunk_size = total_rows / batches;
    let started = Instant::now();

    let mut next_id = 1i64;
    let mut chunk_no = 0i64;
    while next_id <= total_rows {
        conn.execute("BEGIN", [])
            .map_err(|e| logger_core::Error::Db(e.to_string()))?;
        let end = (next_id + chunk_size - 1).min(total_rows);
        {
            let mut stmt = conn
                .prepare("INSERT INTO t_bulk_1m (id, name) VALUES (?, ?)")
                .map_err(|e| logger_core::Error::Db(e.to_string()))?;
            for id in next_id..=end {
                let bound = [
                    RawDuckValue::BigInt(id),
                    RawDuckValue::Text(format!("duckdb-raw-bulk-{id}")),
                ];
                stmt.execute(duck_params_from_iter(bound.iter()))
                    .map_err(|e| logger_core::Error::Db(e.to_string()))?;
            }
        }
        conn.execute("COMMIT", [])
            .map_err(|e| logger_core::Error::Db(e.to_string()))?;
        chunk_no += 1;
        println!("Raw DuckDB bulk progress: batch {chunk_no}/{batches}, inserted {end}/{total_rows}");
        next_id = end + 1;
    }

    let elapsed = started.elapsed();
    println!("\n=== Raw DuckDB 1M bulk artifacts ===");
    println!("DB file: {}", db_path.display());
    println!("Raw DuckDB 1M bulk elapsed: {:.2?}", elapsed);
    Ok(())
}

fn run_raw_duckdb_appender_bulk_demo(root: &Path) -> Result<()> {
    let db_path = root.join("duckdb_raw_appender_bulk_1m.duckdb");
    let mut conn =
        RawDuckDbConnection::open(&db_path).map_err(|e| logger_core::Error::Db(e.to_string()))?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS t_bulk_1m (id INTEGER, name TEXT)",
        [],
    )
    .map_err(|e| logger_core::Error::Db(e.to_string()))?;

    let total_rows = bulk_total_rows();
    let batches = bulk_batches();
    assert_eq!(
        total_rows % batches,
        0,
        "SYNCLITE_TOTAL_ROWS ({total_rows}) must be divisible by SYNCLITE_BATCHES ({batches})"
    );
    let chunk_size = total_rows / batches;
    let started = Instant::now();

    let mut next_id = 1i64;
    let mut chunk_no = 0i64;
    while next_id <= total_rows {
        let end = (next_id + chunk_size - 1).min(total_rows);
        {
            let mut tx = conn
                .transaction()
                .map_err(|e| logger_core::Error::Db(e.to_string()))?;
            tx.set_drop_behavior(DropBehavior::Commit);
            let mut app = tx
                .appender("t_bulk_1m")
                .map_err(|e| logger_core::Error::Db(e.to_string()))?;
            for id in next_id..=end {
                app.append_row(params![id, format!("duckdb-raw-appender-{id}")])
                    .map_err(|e| logger_core::Error::Db(e.to_string()))?;
            }
        }
        chunk_no += 1;
        println!("Raw DuckDB appender progress: batch {chunk_no}/{batches}, inserted {end}/{total_rows}");
        next_id = end + 1;
    }

    let elapsed = started.elapsed();
    println!("\n=== Raw DuckDB Appender 1M bulk artifacts ===");
    println!("DB file: {}", db_path.display());
    println!("Raw DuckDB appender 1M bulk elapsed: {:.2?}", elapsed);
    Ok(())
}

fn write_conf(
    conf_path: &Path,
    device_name: &str,
    engine: &str,
    device_type: &str,
    db_path: &Path,
    stage_dir: &Path,
) {
    fs::create_dir_all(stage_dir).unwrap();
    let body = format!(
        "device-name={device_name}\n\
         db-engine={engine}\n\
         device-type={device_type}\n\
         db-path={}\n\
         local-data-stage-directory={}\n",
        db_path.display().to_string().replace('\\', "/"),
        stage_dir.display().to_string().replace('\\', "/"),
    );
    fs::write(conf_path, body).unwrap();
}

fn print_artifacts(label: &str, root: &Path, device_name: &str, db_path: &Path, stage_dir: &Path) {
    let device_home: PathBuf = format!("{}.synclite", db_path.display()).into();
    let stage_subdir = find_stage_subdir(stage_dir, device_name)
        .unwrap_or_else(|| PathBuf::from("<not-found>"));

    println!("\n=== {label} artifacts ===");
    println!("DB file: {}", db_path.display());
    println!("Device home: {}", device_home.display());
    println!("Stage root: {}", stage_dir.display());
    println!("Stage subdir: {}", stage_subdir.display());

    let print_tree_enabled = std::env::var("SYNCLITE_PRINT_TREE")
        .ok()
        .map(|v| v != "0" && !v.eq_ignore_ascii_case("false"))
        .unwrap_or(true);
    if print_tree_enabled {
        println!("Files under demo root:");
        print_tree(root, 0);
    }
}

fn print_stage_stats(label: &str, stage_dir: &Path, device_name: &str) {
    let Some(stage_subdir) = find_stage_subdir(stage_dir, device_name) else {
        println!("{label}: stage subdir not found");
        return;
    };

    let mut seg_count = 0usize;
    let mut txn_count = 0usize;
    let mut backup_count = 0usize;
    if let Ok(entries) = fs::read_dir(&stage_subdir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.ends_with(".sqllog") {
                seg_count += 1;
            }
            if name.ends_with(".txn") {
                txn_count += 1;
            }
            if name.ends_with(".synclite.backup") {
                backup_count += 1;
            }
        }
    }
    println!(
        "{label} stage stats: segments={seg_count}, txn_files={txn_count}, backups={backup_count}"
    );
}

fn count_distinct_insert_commits(stage_subdir: &Path, table_name: &str) -> usize {
    let mut commits = std::collections::BTreeSet::new();
    let insert_prefix = format!("INSERT INTO {table_name}%");
    let Ok(entries) = fs::read_dir(stage_subdir) else {
        return 0;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let Some(name) = path.file_name().and_then(|s| s.to_str()) else {
            continue;
        };
        if !(name.ends_with(".sqllog") || name.ends_with(".txn")) {
            continue;
        }
        let Ok(conn) = RawSqliteConnection::open(&path) else {
            continue;
        };
        let mut stmt = conn
            .prepare("SELECT DISTINCT commit_id FROM commandlog WHERE sql LIKE ?1")
            .unwrap();
        let rows = stmt
            .query_map([insert_prefix.as_str()], |r| r.get::<_, i64>(0))
            .unwrap();
        for row in rows {
            commits.insert(row.unwrap());
        }
    }
    commits.len()
}

fn find_stage_subdir(stage_dir: &Path, device_name: &str) -> Option<PathBuf> {
    let prefix = format!("synclite-{device_name}-");
    let entries = fs::read_dir(stage_dir).ok()?;
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().to_string();
        if name.starts_with(&prefix) {
            return Some(entry.path());
        }
    }
    None
}

fn print_tree(path: &Path, depth: usize) {
    let indent = "  ".repeat(depth);
    if path.is_file() {
        println!("{}- {}", indent, path.display());
        return;
    }
    println!("{}+ {}", indent, path.display());
    let Ok(entries) = fs::read_dir(path) else {
        return;
    };
    let mut children: Vec<PathBuf> = entries.flatten().map(|e| e.path()).collect();
    children.sort();
    for child in children {
        print_tree(&child, depth + 1);
    }
}

fn demo_root() -> PathBuf {
    let base = std::env::temp_dir().join("synclite-device-artifacts-demo");
    let ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    base.join(format!("run-{ts}"))
}

fn bulk_total_rows() -> i64 {
    std::env::var("SYNCLITE_TOTAL_ROWS")
        .ok()
        .and_then(|v| v.parse::<i64>().ok())
        .filter(|v| *v > 0)
        .unwrap_or(1_000_000)
}

fn bulk_batches() -> i64 {
    std::env::var("SYNCLITE_BATCHES")
        .ok()
        .and_then(|v| v.parse::<i64>().ok())
        .filter(|v| *v > 0)
        .unwrap_or(10)
}





