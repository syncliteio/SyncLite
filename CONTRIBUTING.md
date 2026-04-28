# Contributing to SyncLite

Thank you for your interest in contributing to SyncLite! All contributions are welcome, including:

- Reporting bugs and opening issues
- Fixing bugs and resolving open issues
- Submitting new features and improvements
- Adding or improving integration tests
- Improving documentation
- Building open-source integrations and demos on top of the SyncLite platform
- Reviewing pull requests
- Providing feedback and suggestions

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Security Vulnerabilities](#security-vulnerabilities)
3. [Development Prerequisites](#development-prerequisites)
4. [Getting Started](#getting-started)
5. [Branch Naming](#branch-naming)
6. [Commit Messages](#commit-messages)
7. [Code Style](#code-style)
8. [Testing](#testing)
9. [Pull Request Process](#pull-request-process)
10. [Developer Certificate of Origin (DCO)](#developer-certificate-of-origin-dco)
11. [Issues](#issues)
12. [License](#license)

---

## Code of Conduct

All contributors are expected to follow our [Code of Conduct](./CODE_OF_CONDUCT.md). Please read it before participating.

---

## Security Vulnerabilities

**Do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability, please disclose it responsibly by emailing **security@synclite.io**. Include a description of the issue, steps to reproduce, and any relevant context. We will acknowledge your report within 48 hours and work with you on a coordinated disclosure.

---

## Development Prerequisites

Before contributing code, ensure you have the following installed:

| Tool | Minimum Version | Notes |
|---|---|---|
| Java (JDK) | 25 | Eclipse Temurin recommended: https://adoptium.net |
| Apache Maven | 3.8.6 | https://maven.apache.org/download.cgi |
| Git | 2.x | |

Optional but recommended:
- An IDE with Java and Maven support (IntelliJ IDEA, Eclipse, VS Code + Extension Pack for Java)
- Docker (for running integration test dependencies: PostgreSQL, MySQL, MinIO, SFTP)

---

## Getting Started

1. **Fork the repository** on GitHub.

2. **Clone your fork** (include submodules):
   ```bash
   git clone --recurse-submodules https://github.com/YOUR-USERNAME/SyncLite.git
   cd SyncLite
   ```

3. **Add the upstream remote** so you can keep your fork in sync:
   ```bash
   git remote add upstream https://github.com/syncliteio/SyncLite.git
   ```

4. **Build the project** to verify your environment:
   ```bash
   mvn -Drevision=oss clean install
   ```
   A successful build creates the platform release under `target/synclite-platform-oss/`.

5. **Create a branch** for your change (see [Branch Naming](#branch-naming) below).

6. **Make your changes.** Write clean, focused commits.

7. **Run the tests** (see [Testing](#testing) below).

8. **Push your branch** and open a Pull Request against `main`.

---

## Branch Naming

Use the following conventions:

| Type | Pattern | Example |
|---|---|---|
| Bug fix linked to an issue | `fix/issue-<number>-short-description` | `fix/issue-42-sqlite-log-corruption` |
| Feature linked to an issue | `feat/issue-<number>-short-description` | `feat/issue-78-duckdb-cdc-support` |
| Documentation | `docs/short-description` | `docs/update-qreader-readme` |
| Chore / maintenance | `chore/short-description` | `chore/bump-sqlite-jdbc-version` |

---

## Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. This keeps the history readable and enables automated changelog generation.

```
<type>(<scope>): <short summary>

[optional body]

[optional footer: Signed-off-by, Fixes #issue]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`

**Scope** (optional): name of the affected submodule, e.g. `consolidator`, `logger`, `dbreader`, `qreader`.

**Examples:**
```
feat(logger): add HyperSQL appender device type
fix(consolidator): handle null values in UPSERT mode for MySQL destination
docs: update DBReader README with CDC setup steps
chore(deps): bump sqlite-jdbc to 3.53.0.0
```

- Keep the subject line under 72 characters.
- Use the imperative mood: "add feature" not "added feature".
- Reference issues in the footer: `Fixes #42` or `Closes #42`.

---

## Code Style

SyncLite is a Java project. Please follow [Google's Java Style Guide](https://google.github.io/styleguide/javaguide.html).

Key conventions in use across the codebase:

- 4-space indentation (no tabs)
- `camelCase` for variables and methods; `PascalCase` for classes
- Descriptive variable names; avoid single-letter names outside loop counters
- Javadoc on all public APIs
- No unused imports; organize imports (IDE: Ctrl+Shift+O / Option+Shift+O)
- Avoid raw types; use generics
- Prefer `try-with-resources` for `Closeable` / `AutoCloseable` objects (JDBC connections, streams)
- Log via SLF4J; do not use `System.out.println` in library or server code

---

## Testing

All changes must pass existing tests and, where appropriate, include new tests.

### Unit tests

Run the Maven test phase for the specific submodule you changed:

```bash
# Example: test the logger
cd synclite-logger-java/logger
mvn -Drevision=oss test
```

### Integration tests (SyncLite Validator)

The `synclite-validator` submodule provides end-to-end integration tests that exercise the full pipeline (edge device → staging → consolidation → destination). Run them against a local or Docker-hosted destination database before submitting a PR that affects core consolidation logic.

Refer to [synclite-validator/README.md](synclite-validator/README.md) for setup and run instructions.

### What we check in CI

- `mvn -Drevision=oss clean install` (full multi-module build)
- All unit tests pass
- No compiler warnings treated as errors

---

## Pull Request Process

1. **Keep PRs focused.** One logical change per PR. Large changes are harder to review and more likely to conflict.
2. **Fill in the PR template.** Describe what changed, why, and how it was tested. Link relevant issues.
3. **CI must be green.** All automated checks must pass before review.
4. **Expect review feedback.** Maintainers aim to review PRs within 5 business days. Please be responsive to feedback; PRs with no activity for 30 days may be closed.
5. **Squash or rebase before merge.** Keep the commit history clean; the project uses squash-merge for most PRs.
6. **DCO sign-off is required** (see below).

---

## Developer Certificate of Origin (DCO)

This project uses the [Developer Certificate of Origin (DCO)](https://developercertificate.org/) instead of a Contributor License Agreement (CLA). By signing off your commits you certify that you wrote the code or otherwise have the right to submit it under the Apache License 2.0.

Add a sign-off to every commit using the `-s` flag:

```bash
git commit -s -m "feat(logger): add streaming appender mode"
```

This appends the following line to your commit message:

```
Signed-off-by: Your Name <your.email@example.com>
```

Contributions without a DCO sign-off will not be merged. If you forgot to sign off past commits in an open PR, you can fix them with:

```bash
git rebase --signoff HEAD~<number-of-commits>
git push --force-with-lease
```

---

## Issues

When opening a GitHub issue, prefix the title with the affected component name:

```
synclite-consolidator: Consolidation stops when destination PostgreSQL restarts
synclite-logger: SQLite device throws NPE on second initialize call
synclite-dbreader: CDC replication misses rows on MySQL 8.4 with GTID mode
```

For bugs, please include:
- SyncLite version
- Java version (`java -version`)
- OS / environment
- Steps to reproduce
- Expected vs. actual behaviour
- Relevant log output

For feature requests, describe the use case and the problem it solves, not just the implementation you have in mind.

---

## License

SyncLite is licensed under the [Apache License 2.0](./LICENSE).

By submitting a contribution you agree that:
- Your contribution is your original work (or you have the right to submit it).
- You license your contribution under the Apache License 2.0, as declared by your DCO sign-off.
- You have not included any code under a license incompatible with Apache 2.0.

For the avoidance of doubt, contributions to SyncLite do **not** require you to assign copyright to any individual or entity.

