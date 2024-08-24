#!/usr/bin/env bash

# Set the URL of the tar file to download
URL="https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.93/bin/apache-tomcat-9.0.93.tar.gz"
# Set the destination directory for the downloaded tar file
DESTINATION="."

# Download the tar file using curl
wget -O "$DESTINATION/apache-tomcat-9.0.93.tar.gz" "$URL" --no-check-certificate

# Extract the zip file using unzip
tar -xzf "$DESTINATION/apache-tomcat-9.0.93.tar.gz" -C "$DESTINATION"

# Copy tomcat-users.xml file into extracted tomcat folder
cp -f tomcat-users.xml apache-tomcat-9.0.93/conf/tomcat-users.xml

# Clean up the downloaded zip file
rm $DESTINATION/apache-tomcat-9.0.93.zip


# Set the URL of the tar file to download
URL="https://download.java.net/openjdk/jdk11/ri/openjdk-11+28_linux-x64_bin.tar.gz"

# Set the destination directory for the downloaded tar file
DESTINATION="."

# Download the tar file using curl
wget -O "$DESTINATION/openjdk-11+28_linux-x64_bin.tar.gz" "$URL" --no-check-certificate

# Extract the zip file using unzip
tar -xzf "$DESTINATION/openjdk-11+28_linux-x64_bin.tar.gz" -C "$DESTINATION"

# Clean up the downloaded zip file
rm $DESTINATION/openjdk-11+28_linux-x64_bin.tar.gz

cp -f ../lib/consolidator/synclite-consolidator-*.war apache-tomcat-9.0.93/webapps/synclite-consolidator.war
cp -f ../sample-apps/jsp-servlet/web/target/*.war apache-tomcat-9.0.93/webapps/synclite-sample-app.war
cp -f ../tools/synclite-dbreader/*.war apache-tomcat-9.0.93/webapps/synclite-dbreader.war
cp -f ../tools/synclite-qreader/*.war apache-tomcat-9.0.93/webapps/synclite-qreader.war
cp -f ../tools/synclite-jobmonitor/*.war apache-tomcat-9.0.93/webapps/synclite-jobmonitor.war

