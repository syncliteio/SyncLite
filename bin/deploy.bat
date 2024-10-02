@echo off

REM Set the Tomcat version and URL of the zip file to download
set TOMCAT_VERSION=9.0.95
set URL=https://dlcdn.apache.org/tomcat/tomcat-9/v%TOMCAT_VERSION%/bin/apache-tomcat-%TOMCAT_VERSION%-windows-x64.zip
set "PARENT_DIR=%~dp0"

curl -o apache-tomcat-%TOMCAT_VERSION%.zip %URL%

REM Extract the zip file using PowerShell
powershell -Command "Add-Type -A 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::ExtractToDirectory('apache-tomcat-%TOMCAT_VERSION%.zip', '%PARENT_DIR%')"

REM Copy tomcat-users.xml file into extracted tomcat folder
echo F | xcopy /Y tomcat-users.xml apache-tomcat-%TOMCAT_VERSION%\conf\tomcat-users.xml

del apache-tomcat-%TOMCAT_VERSION%.zip

REM Set the URL of the zip file to download for OpenJDK
set URL=https://download.java.net/openjdk/jdk11/ri/openjdk-11+28_windows-x64_bin.zip

REM Download the OpenJDK zip file using curl
curl -o openjdk-11+28_windows-x64_bin.zip %URL%

REM Extract the zip file using PowerShell
powershell -Command "Add-Type -A 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::ExtractToDirectory('openjdk-11+28_windows-x64_bin.zip', '%PARENT_DIR%')"

REM Clean up the downloaded zip file
del openjdk-11+28_windows-x64_bin.zip

REM Copy war files into the Tomcat webapps directory
echo F | xcopy /Y ..\lib\consolidator\synclite-consolidator-*.war apache-tomcat-%TOMCAT_VERSION%\webapps\synclite-consolidator.war
echo F | xcopy /Y ..\sample-apps\synclite-logger\jsp-servlet\web\target\*.war apache-tomcat-%TOMCAT_VERSION%\webapps\synclite-sample-app.war
echo F | xcopy /Y ..\tools\synclite-dbreader\*.war apache-tomcat-%TOMCAT_VERSION%\webapps\synclite-dbreader.war
echo F | xcopy /Y ..\tools\synclite-qreader\*.war apache-tomcat-%TOMCAT_VERSION%\webapps\synclite-qreader.war
