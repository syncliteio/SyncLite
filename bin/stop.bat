@echo off
setlocal enabledelayedexpansion

for /f "tokens=1" %%a in ('%JAVA_HOME%\bin\jps -l ^| findstr "com.synclite.consolidator.Main"') do (
    set "pid=%%a"
    if defined pid (
        tasklist /fi "pid eq !pid!" | findstr /i "!pid!" >nul
        if !errorlevel! equ 0 (
            taskkill /F /PID !pid!
        )
    )
)

for /f "tokens=1" %%b in ('%JAVA_HOME%\bin\jps -l ^| findstr "org.apache.catalina.startup.Bootstrap"') do (
    set "pid=%%b"
    if defined pid (
        tasklist /fi "pid eq !pid!" | findstr /i "!pid!" >nul
        if !errorlevel! equ 0 (
            taskkill /F /PID !pid!
        )
    )
)

