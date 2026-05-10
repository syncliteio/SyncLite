@echo off
setlocal enabledelayedexpansion
for /f %%E in ('echo prompt $E^| cmd') do set "ESC=%%E"
set "RESET=!ESC![0m"
set "INFO=!ESC![36m"
set "STEP=!ESC![33m"
set "OK=!ESC![32m"
set "ERR=!ESC![31m"

REM Change to the directory containing this script
cd /d "%~dp0"

echo !INFO!========================================!RESET!
echo !INFO!SyncLite Platform Start!RESET!
echo !INFO!========================================!RESET!
echo.

set "TOMCAT_VER=9.0.117"
set "TOMCAT_DIR=apache-tomcat-%TOMCAT_VER%"

REM ── Locate JDK ────────────────────────────────────────────────────────────────
set "JAVA_HOME=%~dp0jdk-25"
echo !STEP![1/3] Checking JDK installation...!RESET!
if not exist "%JAVA_HOME%\bin\java.exe" (
    echo !ERR!ERROR: JDK not found at %JAVA_HOME% - run deploy.bat first.!RESET!
    pause
    exit /b 1
)
echo !OK![1/3] JDK found.!RESET!

REM ── Locate Tomcat ─────────────────────────────────────────────────────────────
echo !STEP![2/3] Checking Tomcat installation...!RESET!
if not exist "%TOMCAT_DIR%\bin\startup.bat" (
    echo !ERR!ERROR: %TOMCAT_DIR% not found - run deploy.bat first.!RESET!
    pause
    exit /b 1
)
echo !OK![2/3] Tomcat found.!RESET!

echo !INFO!Using JAVA_HOME=%JAVA_HOME%!RESET!
echo !INFO!Using Tomcat: %TOMCAT_DIR%!RESET!

set "CATALINA_HOME=%~dp0%TOMCAT_DIR%"
echo !STEP![3/4] Refreshing SyncLite DB WAR deployment...!RESET!
if exist "..\tools\synclite-db\*.war" (
    echo F | xcopy /Y "..\tools\synclite-db\*.war" "%CATALINA_HOME%\webapps\synclite-db.war" >nul
    if errorlevel 1 (
        echo !ERR!ERROR: Failed to refresh SyncLite DB WAR before startup.!RESET!
        pause
        exit /b 1
    )
    echo !OK![3/4] SyncLite DB WAR refreshed.!RESET!
) else (
    echo !OK![3/4] SyncLite DB WAR refresh skipped - packaged GUI WAR not found.!RESET!
)

echo !STEP![4/4] Starting Tomcat...!RESET!
call "%CATALINA_HOME%\bin\startup.bat"
if errorlevel 1 (
    echo !ERR!ERROR: Tomcat startup command failed.!RESET!
    pause
    exit /b 1
)
echo !OK![4/4] Tomcat startup command completed.!RESET!
echo.
echo !OK!Start script finished.!RESET!
pause
endlocal
