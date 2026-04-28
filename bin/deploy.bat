@echo off
setlocal enabledelayedexpansion

REM Change to the directory containing this script
cd /d "%~dp0"

REM ── Versions ──────────────────────────────────────────────────────────────────
set TOMCAT_VER=9.0.117
set JDK_VER=25
set JDK_DIR=jdk-%JDK_VER%

REM ── Download and extract Tomcat ───────────────────────────────────────────────
set TOMCAT_ZIP=apache-tomcat-%TOMCAT_VER%-windows-x64.zip
set TOMCAT_URL=https://dlcdn.apache.org/tomcat/tomcat-9/v%TOMCAT_VER%/bin/%TOMCAT_ZIP%

echo Downloading Apache Tomcat %TOMCAT_VER%...
curl -fL -o "%TOMCAT_ZIP%" "%TOMCAT_URL%"
if errorlevel 1 (echo ERROR: Failed to download Tomcat. & exit /b 1)

echo Extracting Tomcat...
powershell -Command "Expand-Archive -Force -Path '%TOMCAT_ZIP%' -DestinationPath '.'"
if errorlevel 1 (echo ERROR: Failed to extract Tomcat. & exit /b 1)

echo F | xcopy /Y tomcat-users.xml "apache-tomcat-%TOMCAT_VER%\conf\tomcat-users.xml"
del "%TOMCAT_ZIP%"

REM ── Download and extract OpenJDK 25 (Eclipse Temurin) ─────────────────────────
set JDK_ZIP=openjdk-%JDK_VER%-windows-x64.zip
set JDK_URL=https://api.adoptium.net/v3/binary/latest/%JDK_VER%/ga/windows/x64/jdk/hotspot/normal/eclipse

echo Downloading OpenJDK %JDK_VER%...
curl -fL -o "%JDK_ZIP%" "%JDK_URL%"
if errorlevel 1 (echo ERROR: Failed to download OpenJDK. & exit /b 1)

echo Extracting OpenJDK...
powershell -Command "Expand-Archive -Force -Path '%JDK_ZIP%' -DestinationPath 'jdk_tmp'"
if errorlevel 1 (echo ERROR: Failed to extract OpenJDK. & exit /b 1)

REM Rename extracted folder to a stable name (jdk-25)
if exist "%JDK_DIR%" rmdir /s /q "%JDK_DIR%"
set "JDK_MOVED="
for /d %%D in (jdk_tmp\jdk-*) do (
	move "%%D" "%JDK_DIR%" >nul
	set "JDK_MOVED=1"
	goto :jdk_moved
)
:jdk_moved
rmdir /s /q jdk_tmp 2>nul
del "%JDK_ZIP%"

if not defined JDK_MOVED (
	echo ERROR: Extracted JDK folder was not found.
	exit /b 1
)

if not exist "%JDK_DIR%\bin\java.exe" (
	echo ERROR: JDK setup failed. Missing %JDK_DIR%\bin\java.exe
	exit /b 1
)

REM ── Deploy WAR files ──────────────────────────────────────────────────────────
set WEBAPPS=apache-tomcat-%TOMCAT_VER%\webapps
echo Deploying WAR files...
echo F | xcopy /Y "..\lib\consolidator\synclite-consolidator-*.war"                        "%WEBAPPS%\synclite-consolidator.war"
echo F | xcopy /Y "..\sample-apps\synclite-logger\jsp-servlet\web\target\*.war"            "%WEBAPPS%\synclite-sample-app.war"
echo F | xcopy /Y "..\tools\synclite-dbreader\*.war"                                       "%WEBAPPS%\synclite-dbreader.war"
echo F | xcopy /Y "..\tools\synclite-qreader\*.war"                                        "%WEBAPPS%\synclite-qreader.war"
echo F | xcopy /Y "..\tools\synclite-jobmonitor\*.war"                                     "%WEBAPPS%\synclite-jobmonitor.war"

echo Deploy complete.
endlocal
