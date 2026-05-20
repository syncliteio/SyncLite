@echo off
setlocal enabledelayedexpansion
for /f %%E in ('echo prompt $E^| cmd') do set "ESC=%%E"
set "RESET=!ESC![0m"
set "INFO=!ESC![36m"
set "STEP=!ESC![33m"
set "OK=!ESC![32m"
set "WARN=!ESC![93m"

REM Change to the directory containing this script
cd /d "%~dp0"

echo !INFO!========================================!RESET!
echo !INFO!SyncLite Platform Stop!RESET!
echo !INFO!========================================!RESET!
echo.

goto :after_helpers

:hold_window
echo.
if /I "%~1"=="failure" (
    echo !WARN!Stop completed with warnings. Review the messages above, then press any key to close this window.!RESET!
) else (
    echo !OK!Stop completed successfully. Review the messages above, then press any key to close this window.!RESET!
)
pause >nul
exit /b 0

:after_helpers

set "TOMCAT_VER=9.0.117"
set "TOMCAT_DIR=apache-tomcat-%TOMCAT_VER%"

echo !STEP![1/3] Requesting Tomcat shutdown...!RESET!
if exist "%TOMCAT_DIR%\bin\shutdown.bat" (
    echo !INFO!Attempting graceful Tomcat shutdown...!RESET!
    call "%TOMCAT_DIR%\bin\shutdown.bat" >nul 2>&1
    echo !OK![1/3] Shutdown signal sent to Tomcat.!RESET!
) else (
    echo !WARN![1/3] Tomcat shutdown script not found. Skipping graceful shutdown.!RESET!
)

set "JAVA_HOME=%~dp0jdk-25"
echo !STEP![2/3] Checking JDK tools...!RESET!
if not exist "%JAVA_HOME%\bin\jps.exe" (
    echo !WARN!WARNING: jps not found at %JAVA_HOME% - skipping process termination.!RESET!
	call :hold_window failure
    goto :eof
)
echo !OK![2/3] JDK tools found.!RESET!

echo !STEP![3/3] Stopping remaining SyncLite and Tomcat Java processes...!RESET!
for %%C in (
    com.synclite.consolidator.Main
    com.synclite.dbreader.Main
    com.synclite.qreader.Main
    org.apache.catalina.startup.Bootstrap
) do (
    for /f "tokens=1" %%P in ('"%JAVA_HOME%\bin\jps" -l 2^>nul ^| findstr "%%C"') do (
        echo !INFO!Stopping %%C (PID %%P)...!RESET!
        taskkill /F /PID %%P 2>nul
    )
)

echo !OK![3/3] Process termination pass complete.!RESET!
echo.
echo !OK!Stop script finished.!RESET!
call :hold_window success
endlocal

