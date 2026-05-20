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

set "SYS32=%SystemRoot%\System32"
set "PWSH_EXE="
set "PS_EXE="
set "CURL_EXE="
set "TAR_EXE="
set "BITSADMIN_EXE="
set "CERTUTIL_EXE="
set "ROBOCOPY_EXE="

if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PWSH_EXE if defined ProgramW6432 if exist "%ProgramW6432%\PowerShell\7\pwsh.exe" set "PWSH_EXE=%ProgramW6432%\PowerShell\7\pwsh.exe"
if defined SYS32 if exist "%SYS32%\WindowsPowerShell\v1.0\powershell.exe" set "PS_EXE=%SYS32%\WindowsPowerShell\v1.0\powershell.exe"
if defined SYS32 if exist "%SYS32%\curl.exe" set "CURL_EXE=%SYS32%\curl.exe"
if defined SYS32 if exist "%SYS32%\tar.exe" set "TAR_EXE=%SYS32%\tar.exe"
if defined SYS32 if exist "%SYS32%\bitsadmin.exe" set "BITSADMIN_EXE=%SYS32%\bitsadmin.exe"
if defined SYS32 if exist "%SYS32%\certutil.exe" set "CERTUTIL_EXE=%SYS32%\certutil.exe"
if defined SYS32 if exist "%SYS32%\robocopy.exe" set "ROBOCOPY_EXE=%SYS32%\robocopy.exe"

goto :after_helpers

REM =========================================================================
REM Helper: Download file using curl/pwsh/powershell/bitsadmin
REM =========================================================================
:download_file

set "URL=%~1"
set "OUT=%~2"

if defined PWSH_EXE (
	"!PWSH_EXE!" -NoProfile -Command "^$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri '%URL%' -OutFile '%OUT%' -UseBasicParsing; exit 0 } catch { exit 1 }"
	exit /b !ERRORLEVEL!
)

if defined PS_EXE (
	"!PS_EXE!" -NoProfile -Command "^$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri '%URL%' -OutFile '%OUT%' -UseBasicParsing; exit 0 } catch { exit 1 }"
	exit /b !ERRORLEVEL!
)

if defined CURL_EXE (
	"!CURL_EXE!" -fL --ssl-no-revoke -o "%OUT%" "%URL%"
	exit /b !ERRORLEVEL!
)

if defined BITSADMIN_EXE (
	"!BITSADMIN_EXE!" /transfer syncliteDownloadJob /download /priority normal "%URL%" "%OUT%"
	exit /b !ERRORLEVEL!
)

if defined CERTUTIL_EXE (
	"!CERTUTIL_EXE!" -urlcache -split -f "%URL%" "%OUT%" >nul
	exit /b !ERRORLEVEL!
)

echo !ERR!ERROR: No download tool found via built-in Windows locations.!RESET!
exit /b 1

:hold_window
echo.
if /I "%~1"=="failure" (
	echo !ERR!Deployment failed. Review the errors above, then press any key to close this window.!RESET!
) else (
	echo !OK!Deployment completed successfully. Review the messages above, then press any key to close this window.!RESET!
)
pause >nul
exit /b 0

REM --- Helper: extract ZIP archives using available tools (pwsh, powershell, tar, unzip)
:extract_zip
set "ZIP_PATH=%~1"
set "DEST_PATH=%~2"
if defined PWSH_EXE (
	"!PWSH_EXE!" -NoProfile -Command "try { Expand-Archive -Force -Path '%ZIP_PATH%' -DestinationPath '%DEST_PATH%'; exit 0 } catch { exit 1 }"
	exit /b !ERRORLEVEL!
)
if defined PS_EXE (
	"!PS_EXE!" -NoProfile -Command "try { Expand-Archive -Force -Path '%ZIP_PATH%' -DestinationPath '%DEST_PATH%'; exit 0 } catch { exit 1 }"
	exit /b !ERRORLEVEL!
)
if defined TAR_EXE (
	"!TAR_EXE!" -xf "%ZIP_PATH%" -C "%DEST_PATH%"
	exit /b !ERRORLEVEL!
)
echo !ERR!ERROR: No ZIP extractor found via built-in Windows locations.!RESET!
exit /b 1

:copy_file
copy /Y "%~1" "%~2" >nul
exit /b !ERRORLEVEL!

:copy_tree
if defined ROBOCOPY_EXE (
	"!ROBOCOPY_EXE!" "%~1" "%~2" /E /NFL /NDL /NJH /NJS /NC /NS >nul
	set "RC=!ERRORLEVEL!"
	if !RC! LSS 8 exit /b 0
)

if defined PWSH_EXE (
	"!PWSH_EXE!" -NoProfile -Command "try { Copy-Item -Path '%~1\\*' -Destination '%~2' -Recurse -Force; exit 0 } catch { exit 1 }"
	exit /b !ERRORLEVEL!
)

if defined PS_EXE (
	"!PS_EXE!" -NoProfile -Command "try { Copy-Item -Path '%~1\\*' -Destination '%~2' -Recurse -Force; exit 0 } catch { exit 1 }"
	exit /b !ERRORLEVEL!
)

echo !ERR!ERROR: No directory copy tool found (robocopy/powershell).!RESET!
exit /b 1

:after_helpers

goto :after_war_helpers

REM =========================================================================
REM Helper: Resolve and deploy WAR files from packaged or module build outputs
REM =========================================================================
:resolve_war
set "WAR_SOURCE="
:resolve_war_next
if "%~1"=="" exit /b 0
for %%F in (%~1) do if exist "%%~fF" if not defined WAR_SOURCE set "WAR_SOURCE=%%~fF"
if defined WAR_SOURCE exit /b 0
shift
goto :resolve_war_next

:deploy_war
set "WAR_LABEL=%~1"
set "WAR_TARGET=%~2"
set "WAR_ERROR=%~3"
shift
shift
shift
call :resolve_war %1 %2 %3 %4
if not defined WAR_SOURCE (
	echo !ERR!ERROR: !WAR_ERROR!!RESET!
	call :hold_window failure
	exit /b 1
)
echo !INFO!  - Deploying !WAR_LABEL! WAR from !WAR_SOURCE!...!RESET!
call :copy_file "!WAR_SOURCE!" "%WEBAPPS%\!WAR_TARGET!.war"
if errorlevel 1 (
	echo !ERR!ERROR: Failed to deploy !WAR_LABEL! WAR.!RESET!
	call :hold_window failure
	exit /b 1
)
echo !OK!  - !WAR_LABEL! WAR deployed.!RESET!
exit /b 0

:after_war_helpers


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
		call :download_file "%TOMCAT_URL%" "%TOMCAT_ZIP%"
		if errorlevel 1 (echo !ERR!ERROR: Failed to download Tomcat.!RESET! & call :hold_window failure & exit /b 1)
		echo !OK![1/7] Tomcat download complete.!RESET!
	)

	echo !STEP![2/7] Extracting Apache Tomcat...!RESET!
	if exist "%TOMCAT_DIR%" rmdir /s /q "%TOMCAT_DIR%"
	call :extract_zip "%TOMCAT_ZIP%" "."
	if errorlevel 1 (echo !ERR!ERROR: Failed to extract Tomcat.!RESET! & call :hold_window failure & exit /b 1)
	echo !OK![2/7] Tomcat extraction complete.!RESET!
)

echo !STEP![3/7] Configuring Tomcat users...!RESET!
call :copy_file "tomcat-users.xml" "%TOMCAT_DIR%\conf\tomcat-users.xml"
if errorlevel 1 (
	echo !ERR!ERROR: Failed to copy tomcat-users.xml.!RESET!
		call :hold_window failure
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
		call :download_file "%JDK_URL%" "%JDK_ZIP%"
		if errorlevel 1 (echo !ERR!ERROR: Failed to download OpenJDK.!RESET! & call :hold_window failure & exit /b 1)
		echo !OK![4/7] OpenJDK download complete.!RESET!
	)

	echo !STEP![5/7] Extracting OpenJDK %JDK_VER%...!RESET!
	if exist jdk_tmp rmdir /s /q jdk_tmp
	mkdir jdk_tmp
	call :extract_zip "%JDK_ZIP%" "jdk_tmp"
	if errorlevel 1 (echo !ERR!ERROR: Failed to extract OpenJDK.!RESET! & call :hold_window failure & exit /b 1)
	echo !OK![5/7] OpenJDK extraction complete.!RESET!

	REM Rename extracted folder to a stable name (jdk-25)
	if exist "%JDK_DIR%" (
		rmdir /s /q "%JDK_DIR%"
		if exist "%JDK_DIR%" (
			echo !ERR!ERROR: Failed to remove existing %JDK_DIR%. Close any process using it and retry.!RESET!
			call :hold_window failure
			exit /b 1
		)
	)
	set "JDK_MOVED="
	echo !STEP![6/7] Finalizing JDK installation...!RESET!
	for /d %%D in (jdk_tmp\jdk-*) do (
		move "%%D" "%JDK_DIR%" >nul 2>&1
		if errorlevel 1 (
			REM Fallback when move fails due permissions/locks: copy contents then continue
			call :copy_tree "%%D" "%JDK_DIR%"
			if errorlevel 1 (
				echo !ERR!ERROR: Failed to finalize JDK folder from %%D to %JDK_DIR%.!RESET!
				call :hold_window failure
				exit /b 1
			)
		)
		set "JDK_MOVED=1"
	)
	rmdir /s /q jdk_tmp 2>nul

	if not defined JDK_MOVED (
		echo !ERR!ERROR: Extracted JDK folder was not found.!RESET!
		call :hold_window failure
		exit /b 1
	)

	if not exist "%JDK_DIR%\bin\java.exe" (
		echo !ERR!ERROR: JDK setup failed. Missing %JDK_DIR%\bin\java.exe!RESET!
		call :hold_window failure
		exit /b 1
	)
	echo !OK![6/7] JDK installation complete.!RESET!
)

REM ── Deploy WAR files ──────────────────────────────────────────────────────────
set WEBAPPS=apache-tomcat-%TOMCAT_VER%\webapps
echo !STEP![7/7] Deploying WAR files to Tomcat...!RESET!

call :deploy_war "SyncLite Consolidator" "synclite-consolidator" "Consolidator WAR not found in packaged or module build output." "..\lib\consolidator\synclite-consolidator-*.war" "..\..\lib\consolidator\synclite-consolidator-*.war" "..\..\synclite-consolidator\root\web\target\synclite-consolidator-*.war" "..\..\synclite-consolidator\root\web\target\*.war"
if errorlevel 1 exit /b 1
call :deploy_war "SyncLite Sample App" "synclite-sample-app" "Sample app WAR not found in packaged or module build output." "..\sample-apps\synclite-logger\jsp-servlet\web\target\*.war" "..\..\synclite-sample-web-app\web\target\*.war"
if errorlevel 1 exit /b 1
call :deploy_war "SyncLite DB" "synclite-db" "SyncLite DB WAR not found in packaged or module build output." "..\tools\synclite-db\*.war" "..\..\synclite-db\root\web\target\synclite-db-*.war" "..\..\synclite-db\root\web\target\*.war"
if errorlevel 1 exit /b 1
call :deploy_war "SyncLite DBReader" "synclite-dbreader" "DBReader WAR not found in packaged or module build output." "..\tools\synclite-dbreader\*.war" "..\..\synclite-dbreader\root\web\target\synclite-dbreader-*.war" "..\..\synclite-dbreader\root\web\target\*.war"
if errorlevel 1 exit /b 1
call :deploy_war "SyncLite QReader" "synclite-qreader" "QReader WAR not found in packaged or module build output." "..\tools\synclite-qreader\*.war" "..\..\synclite-qreader\root\web\target\synclite-qreader-*.war" "..\..\synclite-qreader\root\web\target\*.war"
if errorlevel 1 exit /b 1
call :deploy_war "SyncLite Job Monitor" "synclite-jobmonitor" "Job Monitor WAR not found in packaged or module build output." "..\tools\synclite-jobmonitor\*.war" "..\..\synclite-job-monitor\root\web\target\synclite-jobmonitor-*.war" "..\..\synclite-job-monitor\root\web\target\*.war"
if errorlevel 1 exit /b 1

echo !OK![7/7] WAR deployment complete.!RESET!
echo.
echo !OK!Deploy complete. Tomcat and JDK are ready under %~dp0.!RESET!
call :hold_window success
endlocal
