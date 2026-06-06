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
set "SCRIPT_DIR=%~dp0"
set "CATALINA_HOME=%SCRIPT_DIR%%TOMCAT_DIR%"
set "CATALINA_BIN=%CATALINA_HOME%\bin"
set "CATALINA_STARTUP=%CATALINA_BIN%\startup.bat"
set "CATALINA_CTL=%CATALINA_BIN%\catalina.bat"
set "CATALINA_WEBAPPS=%CATALINA_HOME%\webapps"

goto :after_helpers

:hold_window
echo.
if /I "%~1"=="failure" (
    echo !ERR!Start failed. Review the errors above, then press any key to close this window.!RESET!
) else (
    echo !OK!Start completed successfully. Review the messages above, then press any key to close this window.!RESET!
)
pause >nul
exit /b 0

:resolve_war
set "WAR_SOURCE="
:resolve_war_next
if "%~1"=="" exit /b 0
for %%F in (%~1) do if exist "%%~fF" if not defined WAR_SOURCE set "WAR_SOURCE=%%~fF"
if defined WAR_SOURCE exit /b 0
shift
goto :resolve_war_next

:copy_file
copy /Y "%~1" "%~2" >nul
exit /b !ERRORLEVEL!

:refresh_war
set "WAR_LABEL=%~1"
set "WAR_TARGET=%~2"
shift
shift
call :resolve_war %1 %2 %3 %4
if defined WAR_SOURCE (
    echo !INFO!  - Using !WAR_LABEL! WAR: !WAR_SOURCE!!RESET!
    call :copy_file "!WAR_SOURCE!" "%CATALINA_WEBAPPS%\!WAR_TARGET!.war"
    if errorlevel 1 (
        echo !ERR!ERROR: Failed to refresh !WAR_LABEL! WAR before startup.!RESET!
        call :hold_window failure
        exit /b 1
    )
    echo !OK!  - !WAR_LABEL! WAR refreshed.!RESET!
) else (
    echo !OK!  - !WAR_LABEL! WAR refresh skipped - no WAR found in packaged or source build locations.!RESET!
)
exit /b 0

:after_helpers

REM ── Locate JDK ────────────────────────────────────────────────────────────────
set "JAVA_HOME=%SCRIPT_DIR%jdk-25"
set "JRE_HOME=%JAVA_HOME%"
echo !STEP![1/4] Checking JDK installation...!RESET!
if not exist "%JAVA_HOME%\bin\java.exe" (
    echo !ERR!ERROR: JDK not found at %JAVA_HOME% - run deploy.bat first.!RESET!
    call :hold_window failure
    exit /b 1
)
echo !OK![1/4] JDK found.!RESET!

REM ── Locate Tomcat ─────────────────────────────────────────────────────────────
echo !STEP![2/4] Checking Tomcat installation...!RESET!
if not exist "%CATALINA_HOME%" (
    echo !ERR!ERROR: %TOMCAT_DIR% not found - run deploy.bat first.!RESET!
    call :hold_window failure
    exit /b 1
)
if not exist "%CATALINA_STARTUP%" (
    echo !ERR!ERROR: Tomcat startup script missing at %CATALINA_STARTUP%.!RESET!
    call :hold_window failure
    exit /b 1
)
if not exist "%CATALINA_CTL%" (
    echo !ERR!ERROR: Tomcat control script missing at %CATALINA_CTL%.!RESET!
    call :hold_window failure
    exit /b 1
)
if not exist "%CATALINA_WEBAPPS%" (
    echo !ERR!ERROR: Tomcat webapps directory missing at %CATALINA_WEBAPPS%.!RESET!
    call :hold_window failure
    exit /b 1
)
echo !OK![2/4] Tomcat found.!RESET!

echo !INFO!Using JAVA_HOME=%JAVA_HOME%!RESET!
echo !INFO!Using JRE_HOME=%JRE_HOME%!RESET!
echo !INFO!Using Tomcat: %TOMCAT_DIR%!RESET!

echo !STEP![3/4] Refreshing WAR deployments...!RESET!
call :refresh_war "SyncLite Consolidator" "synclite-consolidator" "..\tools\synclite-consolidator\synclite-consolidator-*.war" "..\tools\synclite-consolidator\*.war" "..\target\synclite-platform-oss\tools\synclite-consolidator\synclite-consolidator-*.war" "..\synclite-consolidator\root\web\target\synclite-consolidator-*.war" "..\synclite-consolidator\root\web\target\*.war"
if errorlevel 1 exit /b 1
call :refresh_war "SyncLite Sample App" "synclite-sample-app" "..\sample-apps\synclite-logger\jsp-servlet\web\target\*.war" "..\synclite-sample-web-app\web\target\*.war"
if errorlevel 1 exit /b 1
call :refresh_war "SyncLite DB" "synclite-db" "..\tools\synclite-db\*.war" "..\target\synclite-platform-oss\tools\synclite-db\*.war" "..\synclite-db\root\web\target\synclite-db-*.war" "..\synclite-db\root\web\target\*.war"
if errorlevel 1 exit /b 1
call :refresh_war "SyncLite DBReader" "synclite-dbreader" "..\tools\synclite-dbreader\*.war" "..\target\synclite-platform-oss\tools\synclite-dbreader\*.war" "..\synclite-dbreader\root\web\target\synclite-dbreader-*.war" "..\synclite-dbreader\root\web\target\*.war"
if errorlevel 1 exit /b 1
call :refresh_war "SyncLite QReader" "synclite-qreader" "..\tools\synclite-qreader\*.war" "..\target\synclite-platform-oss\tools\synclite-qreader\*.war" "..\synclite-qreader\root\web\target\synclite-qreader-*.war" "..\synclite-qreader\root\web\target\*.war"
if errorlevel 1 exit /b 1
call :refresh_war "SyncLite Job Monitor" "synclite-jobmonitor" "..\tools\synclite-jobmonitor\*.war" "..\target\synclite-platform-oss\tools\synclite-jobmonitor\*.war" "..\synclite-job-monitor\root\web\target\synclite-jobmonitor-*.war" "..\synclite-job-monitor\root\web\target\*.war"
if errorlevel 1 exit /b 1
echo !OK![3/4] WAR refresh completed.!RESET!

echo !STEP![4/4] Starting Tomcat...!RESET!
call "%CATALINA_STARTUP%"
if errorlevel 1 (
    echo !ERR!ERROR: Tomcat startup command failed.!RESET!
    call :hold_window failure
    exit /b 1
)
echo !OK![4/4] Tomcat startup command completed.!RESET!
echo.
echo !OK!Start script finished.!RESET!
call :hold_window success
endlocal
