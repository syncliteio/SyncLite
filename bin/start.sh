#!/usr/bin/env bash
set -euo pipefail

# Change to the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    RESET=''
fi

log_info() {
    printf "%b\n" "${CYAN}$1${RESET}"
}

log_step() {
    printf "%b\n" "${YELLOW}$1${RESET}"
}

log_ok() {
    printf "%b\n" "${GREEN}$1${RESET}"
}

log_error() {
    printf "%b\n" "${RED}$1${RESET}" >&2
}

log_info "========================================"
log_info "SyncLite Platform Start"
log_info "========================================"
echo

TOMCAT_VER="9.0.117"
TOMCAT_DIR="apache-tomcat-${TOMCAT_VER}"

# ── Locate JDK ────────────────────────────────────────────────────────────────
export JAVA_HOME="${SCRIPT_DIR}/jdk-25"
log_step "[1/3] Checking JDK installation..."
if [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
    log_error "ERROR: JDK not found at ${JAVA_HOME} - run deploy.sh first."
    exit 1
fi
log_ok "[1/3] JDK found."

# ── Locate Tomcat ─────────────────────────────────────────────────────────────
log_step "[2/3] Checking Tomcat installation..."
if [[ ! -x "${TOMCAT_DIR}/bin/startup.sh" ]]; then
    log_error "ERROR: ${TOMCAT_DIR} not found - run deploy.sh first."
    exit 1
fi
log_ok "[2/3] Tomcat found."

log_info "Using JAVA_HOME=${JAVA_HOME}"
log_info "Using Tomcat: ${TOMCAT_DIR}"

export CATALINA_HOME="${SCRIPT_DIR}/${TOMCAT_DIR}"
log_step "[3/4] Refreshing SyncLite DB WAR deployment..."
db_wars=(../tools/synclite-db/*.war)
if (( ${#db_wars[@]} > 0 )); then
    cp -f "${db_wars[0]}" "${CATALINA_HOME}/webapps/synclite-db.war"
    log_ok "[3/4] SyncLite DB WAR refreshed."
else
    log_ok "[3/4] SyncLite DB WAR refresh skipped - packaged WAR not found."
fi

log_step "[4/4] Starting Tomcat..."
"${CATALINA_HOME}/bin/startup.sh"
log_ok "[4/4] Tomcat startup command completed."
echo
log_ok "Start script finished."

