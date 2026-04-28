@echo off
setlocal enabledelayedexpansion

REM Change to the directory containing this script
cd /d "%~dp0"

set "TOMCAT_VER=9.0.117"
set "TOMCAT_DIR=apache-tomcat-%TOMCAT_VER%"

if exist "%TOMCAT_DIR%\bin\shutdown.bat" (
    echo Attempting graceful Tomcat shutdown...
    call "%TOMCAT_DIR%\bin\shutdown.bat" >nul 2>&1
)

set "JAVA_HOME=%~dp0jdk-25"
if not exist "%JAVA_HOME%\bin\jps.exe" (
    echo WARNING: jps not found at %JAVA_HOME% - skipping process termination.
    goto :eof
)

for %%C in (
    com.synclite.consolidator.Main
    com.synclite.dbreader.Main
    com.synclite.qreader.Main
    org.apache.catalina.startup.Bootstrap
) do (
    for /f "tokens=1" %%P in ('"%JAVA_HOME%\bin\jps" -l 2^>nul ^| findstr "%%C"') do (
        echo Stopping %%C (PID %%P)...
        taskkill /F /PID %%P 2>nul
    )
)

echo Done.
endlocal

