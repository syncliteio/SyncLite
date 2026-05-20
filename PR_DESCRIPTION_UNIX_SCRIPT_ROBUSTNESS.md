## Title
Harden lifecycle scripts on Windows and Unix, and align operator messaging

## Summary
This change improves reliability and usability of SyncLite deployment lifecycle scripts across both Windows (`.bat`) and Unix (`.sh`) by adding stronger prechecks, fallback behavior for tool availability and WAR discovery, and consistent progress/error messaging.

## Why
- Existing Unix scripts were less robust than the Windows scripts in several edge cases.
- WAR refresh/deploy behavior depended on narrow file locations.
- User-facing logs were inconsistent across deploy/start/stop/docker flows.

## What Changed
- Updated `bin/deploy.bat`
  - Added robust tool detection using absolute system paths where possible.
  - Added resilient download/extract fallback handling.
  - Added WAR source fallback resolution for all deployed apps.
  - Added explicit success/failure close-window prompts for better operator clarity.

- Updated `bin/start.bat`
  - Added startup prechecks for Tomcat/JDK paths.
  - Expanded WAR refresh from DB-only to all deployable apps.
  - Added fallback WAR source resolution.
  - Added clearer success/failure completion messaging.

- Updated `bin/stop.bat`
  - Added clearer completion messaging and close-window behavior.
  - Improved control-flow safety around helper labels.

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
- Windows batch script validation:
  - `& "c:\work\synclite\repos\SyncLite\bin\deploy.bat"` completed successfully.

- Syntax-checked all updated shell scripts with:
  - `bash -n ./bin/deploy.sh`
  - `bash -n ./bin/start.sh`
  - `bash -n ./bin/stop.sh`
  - `bash -n ./bin/docker-deploy.sh`

## Impact
- No Java source or runtime behavior changes outside script orchestration.
- No API or schema changes.
- Operator experience is more predictable for first-time users on both Windows and Linux/macOS.

## Checklist
- [x] Backward-compatible script updates
- [x] Improved fallback behavior for common missing-tool scenarios
- [x] Consistent operator-facing messaging
- [x] Basic static script validation completed