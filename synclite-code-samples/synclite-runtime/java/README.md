# Java Samples

Compile samples against the built logger jar:

javac -cp ..\\..\\target\\synclite-oss.jar *.java

Run any sample (example):

java -cp ..\\..\\target\\synclite-oss.jar;. SyncliteDeviceApp

Notes:
- Samples default to SQLite and include inline comments for replacing SQL-device/appender device types.
- Keep synclite.conf in the current working directory.
