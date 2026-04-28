#!/usr/bin/env bash
set -euo pipefail

# Change to the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

TOMCAT_VER="9.0.117"
TOMCAT_DIR="apache-tomcat-${TOMCAT_VER}"

# ── Locate JDK ────────────────────────────────────────────────────────────────
export JAVA_HOME="${SCRIPT_DIR}/jdk-25"
if [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
    echo "ERROR: JDK not found at ${JAVA_HOME} - run deploy.sh first."
    exit 1
fi

# ── Locate Tomcat ─────────────────────────────────────────────────────────────
if [[ ! -x "${TOMCAT_DIR}/bin/startup.sh" ]]; then
    echo "ERROR: ${TOMCAT_DIR} not found - run deploy.sh first."
    exit 1
fi

echo "Using JAVA_HOME=${JAVA_HOME}"
echo "Using Tomcat: ${TOMCAT_DIR}"

export CATALINA_HOME="${SCRIPT_DIR}/${TOMCAT_DIR}"
"${CATALINA_HOME}/bin/startup.sh"

