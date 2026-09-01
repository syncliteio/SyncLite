# SyncLite Node.js sample

[`synclite_sqlite_postgres.js`](synclite_sqlite_postgres.js) — local SQLite app whose every change is replicated to PostgreSQL by the in-process consolidator. Drives the SyncLite Rust runtime via the [`synclite`](https://www.npmjs.com/package/synclite) N-API binding — no JVM, no jar.

Top-of-file comments show where to flip **sync mode** (`REPLICATION` ↔ `CONSOLIDATION` — see [../README.md § Sync modes](../README.md#sync-modes-replication-vs-consolidation)) and swap connection settings.

## Quickest start — install from npm

```bash
npm install synclite@1.1.0
```

That's it — npm automatically installs the matching native optional dependency
(`@synclite/native-win32-x64-msvc`, `@synclite/native-linux-x64-gnu`, or
`@synclite/native-linux-arm64-gnu`). It runs without a repo checkout or Rust
toolchain on Windows x64, Linux x86_64, and Linux aarch64. Then skip straight
to [step 2](#2-install-pg-for-the-post-sync-postgres-verification) to add the
Postgres client and run the sample.

Prefer to run entirely offline from an extracted release zip? Use [Run from the release zip](#run-from-the-release-zip) below instead.

## Run from the release zip

You are already in `sample-apps/nodejs/` of an extracted release. The release ships the `synclite` npm tarball under [`../../lib/nodejs/`](../../lib/nodejs/).

### 1. Install the bundled packages

```bash
node install-synclite.js
```

The installer detects your OS/architecture and installs `synclite-1.1.0.tgz`
plus its matching scoped native package from `../../lib/nodejs/`. It works
unchanged on Windows x64, Linux x86_64, and Linux aarch64 — no registry access,
native build, or manual platform selection required.

> For a registry install, use `npm install synclite`. npm resolves the matching
> `@synclite/native-<platform>` optional dependency automatically.

### 2. Install `pg` (for the post-sync Postgres verification)

```bash
npm install pg
```

If `pg` is missing the sample still runs the local flow and just skips the `[POSTGRES ...]` verification block.

### 3. Pre-create the Postgres database (one-time)

```sql
CREATE DATABASE syncdb;
```

Defaults: `postgresql://postgres:postgres@localhost:5432/syncdb`, schema `syncschema` (auto-created by the consolidator on first run). Edit `POSTGRES_URL` at the top of the `.js` to override.

### 4. Run

```bash
node synclite_sqlite_postgres.js
```

Safe to rerun — each table is `DROP TABLE IF EXISTS`'d before being recreated.

## What you'll see

Three flows executed locally on SQLite, each step printing a `[LOCAL ...]` banner:

1. **users** — `INSERT` / `UPDATE` / batched `INSERT`.
2. **products** — `ALTER TABLE ADD / RENAME / DROP COLUMN`.
3. **orders → orders_archive** — `ALTER TABLE RENAME TO`.

Then `awaitSync` blocks until the in-process shipper + consolidator have drained to Postgres, and a `[POSTGRES …]` block reconnects with `pg` and prints the same rows + same schema from the destination.

## Troubleshooting

- **`Error: io error: The filename, directory name, or volume label syntax is incorrect`** — ensure `synclite-stage` and `synclite-work` directories are created; the sample auto-creates them now.
- **`Error: Cannot find module 'synclite'`** — re-run step 1.
- **`Error: Cannot find module 'pg'`** — `npm install pg`, or ignore (sample skips verification).
- **Nothing landed on Postgres** — check the trace files documented in [../README.md § Where do the samples write files?](../README.md#where-do-the-samples-write-files).

---

## Developing against the repo

If you're working from a `synclite` repo checkout instead of an extracted release, install from the built npm tarball:

```bash
npm install ../../synclite-logger-rust/nodejs/dist/synclite-1.1.0-<tag>.tgz
```

Or build from source by running the root Maven build, which produces the tarball and places it in the release staging area
```

The Node addon is built by napi-rs from `crates/logger/bindings-node` and embeds the same Rust logger, shipper, and consolidator runtime used by the Python wheel.

### Build all release packages

The host package is built on the current OS. Maven builds the Linux x64 and
Linux ARM64 packages when standalone Zig and `cargo-zigbuild` are available;
macOS packages must be built on macOS hosts because the Apple SDK is not
cross-built from Windows/Linux.

On Windows, install the Linux build prerequisites inside WSL:

```bash
sudo apt update
sudo apt install -y build-essential cmake nodejs npm
rustup toolchain install 1.86.0
cargo install cargo-zigbuild
# Install Zig separately and make the `zig` executable available on PATH.
```

Install the napi-rs CLI in the Node package directory:

```bash
cd synclite-logger-rust/nodejs
npm install
```

Then run the full Maven package build from the repository root:

```powershell
mvn -Drevision=1.1.0 clean install
```

The resulting artifacts are staged under:

```text
target/synclite-platform-1.1.0/lib/nodejs/
```

If WSL/Linux, Zig, or the Linux toolchain is unavailable, Maven still builds
the host package and skips the Linux packages with a build-strategy message. Use
`-DskipNodePackage=true` to disable all Node package builds explicitly.
