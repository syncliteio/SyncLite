@echo off

REM Set the URL of the zip file to download
set URL=https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.95/bin/apache-tomcat-9.0.95-windows-x64.zip
set "PARENT_DIR=%~dp0"

curl -o apache-tomcat-9.0.95.zip %URL%

REM Extract the zip file using expand
powershell -Command "Add-Type -A 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::ExtractToDirectory('apache-tomcat-9.0.95.zip', '%PARENT_DIR%')"

REM Copy tomcat-users.xml file into extracted tomcat folder
echo F | xcopy /Y tomcat-users.xml apache-tomcat-9.0.95\conf\tomcat-users.xml

del apache-tomcat-9.0.95.zip

REM Set the URL of the zip file to download
set URL=https://download.java.net/openjdk/jdk11/ri/openjdk-11+28_windows-x64_bin.zip
set "PARENT_DIR=%~dp0"


REM Set the destination directory for the downloaded zip file

REM Download the zip file using curl
curl -o openjdk-11+28_windows-x64_bin.zip %URL%

REM Extract the zip file using expand
REM expand -r openjdk-11+28_windows-x64_bin.zip -d %PARENT_DIR%
powershell -Command "Add-Type -A 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::ExtractToDirectory('openjdk-11+28_windows-x64_bin.zip', '%PARENT_DIR%')"


REM Clean up the downloaded zip file
del openjdk-11+28_windows-x64_bin.zip

echo F | xcopy /Y ..\lib\consolidator\synclite-consolidator-*.war apache-tomcat-9.0.95\webapps\synclite-consolidator.war
echo F | xcopy /Y ..\sample-apps\synclite-logger\jsp-servlet\web\target\*.war apache-tomcat-9.0.95\webapps\synclite-sample-app.war
echo F | xcopy /Y ..\tools\synclite-dbreader\*.war apache-tomcat-9.0.95\webapps\synclite-dbreader.war
echo F | xcopy /Y ..\tools\synclite-qreader\*.war apache-tomcat-9.0.95\webapps\synclite-qreader.war
echo F | xcopy /Y ..\tools\synclite-jobmonitor\*.war apache-tomcat-9.0.95\webapps\synclite-jobmonitor.war
