# Spring Boot logging filter smoke sample

This is a minimal Spring Boot 3 application that proves a published SyncLite
fat JAR can coexist with Spring Boot Logback without changing, renaming, or
republishing SyncLite.

The Maven build copies `io.synclite:synclite` into this sample's `target/`
directory, removes its embedded `org/slf4j/**` and legacy
`org/apache/commons/logging/**` classes from that temporary copy, and replaces
the nested SyncLite JAR in the resulting Boot executable. The artifact in the
Maven repository is never edited.

The dependency declaration also excludes SyncLite's separately resolved
Reload4j, SLF4J, and legacy Commons Logging artifacts, so Boot packages only
its Logback and Spring JCL implementations. The filtered SyncLite copy retains
its embedded Reload4j classes for device traces.

The replacement step intentionally stores, rather than compresses, entries in
the final executable JAR because the Spring Boot launcher requires nested
libraries to be stored.

## Prerequisites

- Java 17 or later.
- Maven 3.9 or later.
- SyncLite `1.2.0` available from the configured Maven repository or the local
  Maven cache.

Do not add `org.slf4j:log4j-over-slf4j`: SyncLite retains Reload4j for its
device trace files, and that bridge conflicts with Reload4j's Log4j-compatible
API classes.

## Run

From this directory:

```powershell
mvn clean package
java -jar target\spring-boot-filter-smoke-1.0.0.jar
```

Expected output includes:

```text
SLF4J_FACTORY=ch.qos.logback.classic.LoggerContext
SYNCLITE_CLASS=io.synclite.SQLite
SYNCLITE_TRACE=<temporary directory>\trace.db.synclite\trace.db.trace
```

The final line is an assertion that SyncLite's direct Reload4j device tracing
continues to work in the filtered Boot package. The smoke test deliberately
performs one rejected reinitialization, then confirms that the trace file has
logged content.

Inspect the filtered nested JAR if needed:

```powershell
jar tf target\synclite-boot-filter\synclite-boot-safe.jar | Select-String org/slf4j
```

The command produces no output because no embedded SLF4J API or provider
classes remain. The original copied input remains at
`target/synclite-boot-filter/synclite-original.jar`.

## Use in an application

Copy the three build plugins from this sample's `pom.xml` into the consuming
Spring Boot Maven application and retain the normal SyncLite dependency. The
complete Hibernate/SQLite/PostgreSQL setup is documented in
[Spring Boot + Hibernate guide](../../../DOCUMENTATION.md#spring-boot-and-hibernate).
