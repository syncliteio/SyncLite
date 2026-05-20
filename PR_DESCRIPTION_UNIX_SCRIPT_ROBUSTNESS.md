## Title
Harden Unix lifecycle scripts and align operator messaging

## Summary
This change improves reliability and usability of the Unix deployment lifecycle scripts by adding tool prechecks, fallback behavior for downloads and WAR discovery, and consistent progress/error messaging.

## Why
- Existing Unix scripts were less robust than the Windows scripts in several edge cases.
- WAR refresh/deploy behavior depended on narrow file locations.
- User-facing logs were inconsistent across deploy/start/stop/docker flows.

## What Changed
- Updated `bin/deploy.sh`
  - Added required tool checks.
  - Added download fallback (`curl` -> `wget`).
  - Added WAR resolution fallback across packaged and module build locations.
  - Preserved structured step logging.

- Updated `bin/start.sh`
  - Added stronger Tomcat path validation.
  - Added `JRE_HOME` export alongside `JAVA_HOME`.
  - Expanded WAR refresh from DB-only to all deployable apps.
  - Added WAR source fallback resolution and consistent messaging.

- Updated `bin/stop.sh`
  - Added explicit warning path when `pgrep` is unavailable.
  - Standardized completion messaging for warning vs success flows.

- Updated `bin/docker-deploy.sh`
  - Added helper logging functions (`info`, `step`, `ok`, `error`).
  - Added required tool check for packaging.
  - Standardized step-based progress messages and clearer docker-daemon error guidance.

## Validation
- Syntax-checked all updated shell scripts with:
  - `bash -n ./bin/deploy.sh`
  - `bash -n ./bin/start.sh`
  - `bash -n ./bin/stop.sh`
  - `bash -n ./bin/docker-deploy.sh`

## Impact
- No Java source or runtime behavior changes outside script orchestration.
- No API or schema changes.
- Linux/macOS operational experience becomes more predictable for first-time users.

## Checklist
- [x] Backward-compatible script updates
- [x] Improved fallback behavior for common missing-tool scenarios
- [x] Consistent operator-facing messaging
- [x] Basic static script validation completed