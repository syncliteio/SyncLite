# Changelog

## SyncLite 1.1.0

- SyncLite Consolidator: added SQL Server destination support, tightened MSSQL type mapping, and fixed column-rename SQL generation for SQL Server.
- SyncLite Logger (Rust): added Node.js N-API bindings, offline packaging helpers, Windows DLL handling, and idle-segment/transaction logging improvements.
- SyncLite Logger (Java): improved transaction logging, device validation, segment locking, and cross-compiled JNI native support.
- SyncLite Client: cleaned up the CLI, aligned it with the DB API changes, and refreshed project docs and packaging metadata.
- Sample Web App: added embedded consolidator support, validation hooks, and dynamic UI behavior updates for deployment workflows.
- SyncLite DB: refreshed startup/docs guidance, updated versioning, and extended result-set metadata/format support for the DB server.
- Platform/docs: expanded README and getting-started content for SQLite, Node.js, Rust, and Python usage, plus final 1.1.0 versioning updates.

---

## SyncLite 1.0.0

- SyncLite DB: shipped the initial DB server with HTTP/JSON access, startup docs, and core API behavior for the public release.
- SyncLite Client: introduced the initial CLI/client integration and aligned the project with the DB server API and documentation updates.
- SyncLite Logger: launched the logger stack with Java/JDBC and native runtime support, plus initial cross-compile and packaging work.
- SyncLite Consolidator: established the core sync pipeline for applying captured changes to destination databases.
- Sample Web App: delivered the initial sample web application and deployment-ready integration points for the platform.
- Platform/docs: published the first full SyncLite platform bundle, onboarding guides, and release documentation for the 1.0.0 release.
