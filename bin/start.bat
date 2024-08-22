@echo off

REM Get the absolute path of the parent directory
set "PARENT_DIR=%~dp0"

set JAVA_HOME=%PARENT_DIR%jdk-11

cd apache-tomcat-9.0.93\bin
startup.bat
