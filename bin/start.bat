@echo off
setlocal enabledelayedexpansion

REM Change to the directory containing this script
cd /d "%~dp0"

set "TOMCAT_VER=9.0.117"
set "TOMCAT_DIR=apache-tomcat-%TOMCAT_VER%"

REM ── Locate JDK ────────────────────────────────────────────────────────────────
set "JAVA_HOME=%~dp0jdk-25"
if not exist "%JAVA_HOME%\bin\java.exe" (
    echo ERROR: JDK not found at %JAVA_HOME% - run deploy.bat first.
    exit /b 1
)

REM ── Locate Tomcat ─────────────────────────────────────────────────────────────
if not exist "%TOMCAT_DIR%\bin\startup.bat" (
    echo ERROR: %TOMCAT_DIR% not found - run deploy.bat first.
    exit /b 1
)

echo Using JAVA_HOME=%JAVA_HOME%
echo Using Tomcat: %TOMCAT_DIR%

set "CATALINA_HOME=%~dp0%TOMCAT_DIR%"
call "%CATALINA_HOME%\bin\startup.bat"
endlocal
