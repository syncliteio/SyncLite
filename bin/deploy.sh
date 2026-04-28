#!/usr/bin/env bash
set -euo pipefail

# Change to the directory containing this script
cd "$(cd "$(dirname "$0")" && pwd)"

# ── Versions ──────────────────────────────────────────────────────────────────
TOMCAT_VER="9.0.117"
JDK_VER="25"
JDK_DIR="jdk-${JDK_VER}"

# ── Download and extract Tomcat ───────────────────────────────────────────────
TOMCAT_TGZ="apache-tomcat-${TOMCAT_VER}.tar.gz"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VER}/bin/${TOMCAT_TGZ}"

echo "Downloading Apache Tomcat ${TOMCAT_VER}..."
curl -fsSL -o "${TOMCAT_TGZ}" "${TOMCAT_URL}"
tar -xzf "${TOMCAT_TGZ}"
cp -f tomcat-users.xml "apache-tomcat-${TOMCAT_VER}/conf/tomcat-users.xml"
chmod +x "apache-tomcat-${TOMCAT_VER}/bin/"*.sh
rm -f "${TOMCAT_TGZ}"

# ── Download and extract OpenJDK 25 (Eclipse Temurin) ─────────────────────────
JDK_TGZ="openjdk-${JDK_VER}-linux-x64.tar.gz"
JDK_URL="https://api.adoptium.net/v3/binary/latest/${JDK_VER}/ga/linux/x64/jdk/hotspot/normal/eclipse"

echo "Downloading OpenJDK ${JDK_VER}..."
curl -fsSL -o "${JDK_TGZ}" "${JDK_URL}"
mkdir -p jdk_tmp
tar -xzf "${JDK_TGZ}" -C jdk_tmp
# Rename extracted folder to a stable name (jdk-25)
rm -rf "${JDK_DIR}"
mv jdk_tmp/jdk-* "${JDK_DIR}"
rm -rf jdk_tmp
rm -f "${JDK_TGZ}"

if [[ ! -x "${JDK_DIR}/bin/java" ]]; then
	echo "ERROR: JDK setup failed. Missing ${JDK_DIR}/bin/java"
	exit 1
fi

# ── Deploy WAR files ──────────────────────────────────────────────────────────
WEBAPPS="apache-tomcat-${TOMCAT_VER}/webapps"
echo "Deploying WAR files..."
cp -f ../lib/consolidator/synclite-consolidator-*.war                         "${WEBAPPS}/synclite-consolidator.war"
cp -f ../sample-apps/synclite-logger/jsp-servlet/web/target/*.war             "${WEBAPPS}/synclite-sample-app.war"
cp -f ../tools/synclite-dbreader/*.war                                         "${WEBAPPS}/synclite-dbreader.war"
cp -f ../tools/synclite-qreader/*.war                                          "${WEBAPPS}/synclite-qreader.war"
cp -f ../tools/synclite-jobmonitor/*.war                                       "${WEBAPPS}/synclite-jobmonitor.war"

echo "Deploy complete."

