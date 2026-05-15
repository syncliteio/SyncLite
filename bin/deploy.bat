@echo off
setlocal enabledelayedexpansion
for /f %%E in ('echo prompt $E^| cmd') do set "ESC=%%E"
set "RESET=!ESC![0m"
set "INFO=!ESC![36m"
set "STEP=!ESC![33m"
set "OK=!ESC![32m"
set "WARN=!ESC![93m"
set "ERR=!ESC![31m"

REM Change to the directory containing this script
cd /d "%~dp0"

echo !INFO!========================================!RESET!
echo !INFO!SyncLite Platform Deploy!RESET!
echo !INFO!========================================!RESET!
echo.

REM ── Versions ──────────────────────────────────────────────────────────────────
set TOMCAT_VER=9.0.117
set JDK_VER=25
set TOMCAT_DIR=apache-tomcat-%TOMCAT_VER%
set JDK_DIR=jdk-%JDK_VER%

goto :after_extract_helper

REM --- Helper: extract ZIP archives using available tools (pwsh, powershell, tar, unzip)
:extract_zip
set "ZIP_PATH=%~1"
set "DEST_PATH=%~2"
where pwsh >nul 2>&1
if %errorlevel%==0 (
	pwsh -NoProfile -Command "Expand-Archive -Force -Path '%ZIP_PATH%' -DestinationPath '%DEST_PATH%'; exit $LASTEXITCODE"
	exit /b %ERRORLEVEL%
)
where powershell >nul 2>&1
if %errorlevel%==0 (
		  if defined SystemRoot (set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe") else set "PS_EXE=powershell"
		  !PS_EXE! -NoProfile -Command "Expand-Archive -Force -Path '%ZIP_PATH%' -DestinationPath '%DEST_PATH%'; exit $LASTEXITCODE"
		  exit /b !ERRORLEVEL!
)
where tar >nul 2>&1
if %errorlevel%==0 (
		  tar -xf "%ZIP_PATH%" -C "%DEST_PATH%"
		  exit /b !ERRORLEVEL!
)
where unzip >nul 2>&1
if %errorlevel%==0 (
		  unzip -o "%ZIP_PATH%" -d "%DEST_PATH%"
		  exit /b !ERRORLEVEL!
)
echo !ERR!ERROR: No archive extractor found (pwsh/powershell/tar/unzip).!RESET!
exit /b 1

:after_extract_helper


REM ── Download and extract Tomcat ───────────────────────────────────────────────
set TOMCAT_ZIP=apache-tomcat-%TOMCAT_VER%-windows-x64.zip
set TOMCAT_URL=https://dlcdn.apache.org/tomcat/tomcat-9/v%TOMCAT_VER%/bin/%TOMCAT_ZIP%

set "TOMCAT_READY="
if exist "%TOMCAT_DIR%\conf\server.xml" if exist "%TOMCAT_DIR%\bin\catalina.bat" set "TOMCAT_READY=1"

if defined TOMCAT_READY (
	echo !OK![1/7] Reusing existing Apache Tomcat %TOMCAT_VER%.!RESET!
	echo !OK![2/7] Tomcat extraction skipped - existing installation is healthy.!RESET!
) else (
	if exist "%TOMCAT_ZIP%" (
		echo !OK![1/7] Reusing downloaded Apache Tomcat archive %TOMCAT_ZIP%.!RESET!
	) else (
		echo !STEP![1/7] Downloading Apache Tomcat %TOMCAT_VER%...!RESET!
		curl -fL --ssl-no-revoke -o "%TOMCAT_ZIP%" "%TOMCAT_URL%"
		if errorlevel 1 (echo !ERR!ERROR: Failed to download Tomcat.!RESET! & pause & exit /b 1)
		echo !OK![1/7] Tomcat download complete.!RESET!
	)

	echo !STEP![2/7] Extracting Apache Tomcat...!RESET!
	if exist "%TOMCAT_DIR%" rmdir /s /q "%TOMCAT_DIR%"
	call :extract_zip "%TOMCAT_ZIP%" "."
	if errorlevel 1 (echo !ERR!ERROR: Failed to extract Tomcat.!RESET! & pause & exit /b 1)
	echo !OK![2/7] Tomcat extraction complete.!RESET!
)

echo !STEP![3/7] Configuring Tomcat users...!RESET!
echo F | xcopy /Y tomcat-users.xml "%TOMCAT_DIR%\conf\tomcat-users.xml"
if errorlevel 1 (
	echo !ERR!ERROR: Failed to copy tomcat-users.xml.!RESET!
	pause
	exit /b 1
)
echo !OK![3/7] Tomcat user configuration complete.!RESET!

REM ── Download and extract OpenJDK 25 (Eclipse Temurin) ─────────────────────────
set JDK_ZIP=openjdk-%JDK_VER%-windows-x64.zip
set JDK_URL=https://api.adoptium.net/v3/binary/latest/%JDK_VER%/ga/windows/x64/jdk/hotspot/normal/eclipse

set "JDK_READY="
if exist "%JDK_DIR%\bin\java.exe" set "JDK_READY=1"

if defined JDK_READY (
	echo !OK![4/7] Reusing existing OpenJDK %JDK_VER%.!RESET!
	echo !OK![5/7] OpenJDK extraction skipped - existing installation is healthy.!RESET!
	echo !OK![6/7] JDK installation already complete.!RESET!
) else (
	if exist "%JDK_ZIP%" (
		echo !OK![4/7] Reusing downloaded OpenJDK archive %JDK_ZIP%.!RESET!
	) else (
		echo !STEP![4/7] Downloading OpenJDK %JDK_VER%...!RESET!
		curl -fL --ssl-no-revoke -o "%JDK_ZIP%" "%JDK_URL%"
		if errorlevel 1 (echo !ERR!ERROR: Failed to download OpenJDK.!RESET! & pause & exit /b 1)
		echo !OK![4/7] OpenJDK download complete.!RESET!
	)

	echo !STEP![5/7] Extracting OpenJDK %JDK_VER%...!RESET!
	if exist jdk_tmp rmdir /s /q jdk_tmp
	call :extract_zip "%JDK_ZIP%" "jdk_tmp"
	if errorlevel 1 (echo !ERR!ERROR: Failed to extract OpenJDK.!RESET! & pause & exit /b 1)
	echo !OK![5/7] OpenJDK extraction complete.!RESET!

	REM Rename extracted folder to a stable name (jdk-25)
	if exist "%JDK_DIR%" (
		rmdir /s /q "%JDK_DIR%"
		if exist "%JDK_DIR%" (
			echo !ERR!ERROR: Failed to remove existing %JDK_DIR%. Close any process using it and retry.!RESET!
			pause
			exit /b 1
		)
	)
	set "JDK_MOVED="
	echo !STEP![6/7] Finalizing JDK installation...!RESET!
	for /d %%D in (jdk_tmp\jdk-*) do (
		move "%%D" "%JDK_DIR%" >nul 2>&1
		if errorlevel 1 (
			REM Fallback when move fails due permissions/locks: copy contents then continue
			xcopy "%%D\*" "%JDK_DIR%\\" /E /I /H /Y >nul
			if errorlevel 1 (
				echo !ERR!ERROR: Failed to finalize JDK folder from %%D to %JDK_DIR%.!RESET!
				pause
				exit /b 1
			)
		)
		set "JDK_MOVED=1"
	)
	rmdir /s /q jdk_tmp 2>nul

	if not defined JDK_MOVED (
		echo !ERR!ERROR: Extracted JDK folder was not found.!RESET!
		pause
		exit /b 1
	)

	if not exist "%JDK_DIR%\bin\java.exe" (
		echo !ERR!ERROR: JDK setup failed. Missing %JDK_DIR%\bin\java.exe!RESET!
		pause
		exit /b 1
	)
	echo !OK![6/7] JDK installation complete.!RESET!
)

REM ── Deploy WAR files ──────────────────────────────────────────────────────────
set WEBAPPS=apache-tomcat-%TOMCAT_VER%\webapps
echo !STEP![7/7] Deploying WAR files to Tomcat...!RESET!

dir /b "..\lib\consolidator\synclite-consolidator-*.war" >nul 2>&1
if errorlevel 1 (
	echo !ERR!ERROR: Consolidator WAR not found under ..\lib\consolidator.!RESET!
	pause
	exit /b 1
)
echo !INFO!  - Deploying SyncLite Consolidator WAR...!RESET!
echo F | xcopy /Y "..\lib\consolidator\synclite-consolidator-*.war" "%WEBAPPS%\synclite-consolidator.war"
if errorlevel 1 (
	echo !ERR!ERROR: Failed to deploy SyncLite Consolidator WAR.!RESET!
	pause
	exit /b 1
)
echo !OK!  - SyncLite Consolidator WAR deployed.!RESET!

dir /b "..\sample-apps\synclite-logger\jsp-servlet\web\target\*.war" >nul 2>&1
if errorlevel 1 (
	echo !ERR!ERROR: Sample app WAR not found under ..\sample-apps\synclite-logger\jsp-servlet\web\target.!RESET!
	pause
	exit /b 1
)
echo !INFO!  - Deploying SyncLite Sample App WAR...!RESET!
echo F | xcopy /Y "..\sample-apps\synclite-logger\jsp-servlet\web\target\*.war" "%WEBAPPS%\synclite-sample-app.war"
if errorlevel 1 (
	echo !ERR!ERROR: Failed to deploy SyncLite Sample App WAR.!RESET!
	pause
	exit /b 1
)
echo !OK!  - SyncLite Sample App WAR deployed.!RESET!

dir /b "..\tools\synclite-db\*.war" >nul 2>&1
if errorlevel 1 (
	echo !ERR!ERROR: SyncLite DB WAR not found under ..\tools\synclite-db.!RESET!
	pause
	exit /b 1
)
echo !INFO!  - Deploying SyncLite DB WAR...!RESET!
echo F | xcopy /Y "..\tools\synclite-db\*.war" "%WEBAPPS%\synclite-db.war"
if errorlevel 1 (
	echo !ERR!ERROR: Failed to deploy SyncLite DB WAR.!RESET!
	pause
	exit /b 1
)
echo !OK!  - SyncLite DB WAR deployed.!RESET!

dir /b "..\tools\synclite-dbreader\*.war" >nul 2>&1
if errorlevel 1 (
	echo !ERR!ERROR: DBReader WAR not found under ..\tools\synclite-dbreader.!RESET!
	pause
	exit /b 1
)
echo !INFO!  - Deploying SyncLite DBReader WAR...!RESET!
echo F | xcopy /Y "..\tools\synclite-dbreader\*.war" "%WEBAPPS%\synclite-dbreader.war"
if errorlevel 1 (
	echo !ERR!ERROR: Failed to deploy SyncLite DBReader WAR.!RESET!
	pause
	exit /b 1
)
echo !OK!  - SyncLite DBReader WAR deployed.!RESET!

dir /b "..\tools\synclite-qreader\*.war" >nul 2>&1
if errorlevel 1 (
	echo !ERR!ERROR: QReader WAR not found under ..\tools\synclite-qreader.!RESET!
	pause
	exit /b 1
)
echo !INFO!  - Deploying SyncLite QReader WAR...!RESET!
echo F | xcopy /Y "..\tools\synclite-qreader\*.war" "%WEBAPPS%\synclite-qreader.war"
if errorlevel 1 (
	echo !ERR!ERROR: Failed to deploy SyncLite QReader WAR.!RESET!
	pause
	exit /b 1
)
echo !OK!  - SyncLite QReader WAR deployed.!RESET!

dir /b "..\tools\synclite-jobmonitor\*.war" >nul 2>&1
if errorlevel 1 (
	echo !ERR!ERROR: Job Monitor WAR not found under ..\tools\synclite-jobmonitor.!RESET!
	pause
	exit /b 1
)
echo !INFO!  - Deploying SyncLite Job Monitor WAR...!RESET!
echo F | xcopy /Y "..\tools\synclite-jobmonitor\*.war" "%WEBAPPS%\synclite-jobmonitor.war"
if errorlevel 1 (
	echo !ERR!ERROR: Failed to deploy SyncLite Job Monitor WAR.!RESET!
	pause
	exit /b 1
)
echo !OK!  - SyncLite Job Monitor WAR deployed.!RESET!

echo !OK![7/7] WAR deployment complete.!RESET!
echo.
echo !OK!Deploy complete. Tomcat and JDK are ready under %~dp0.!RESET!
pause
endlocal
