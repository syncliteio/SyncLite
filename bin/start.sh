#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

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

resolve_war() {
    local pattern
    local matches=()
    for pattern in "$@"; do
        matches=( ${pattern} )
        if (( ${#matches[@]} > 0 )); then
            printf '%s\n' "${matches[0]}"
            return 0
        fi
    done
    return 1
}

refresh_war() {
    local label="$1"
    local target_name="$2"
    shift 2
    local source_path

    if source_path="$(resolve_war "$@")"; then
        log_info "  - Using ${label} WAR: ${source_path}"
        cp -f "${source_path}" "${CATALINA_WEBAPPS}/${target_name}.war"
        log_ok "  - ${label} WAR refreshed."
    else
        log_ok "  - ${label} WAR refresh skipped - no WAR found in packaged or source build locations."
    fi
}

log_info "========================================"
log_info "SyncLite Platform Start"
log_info "========================================"
echo

TOMCAT_VER="9.0.117"
TOMCAT_DIR="apache-tomcat-${TOMCAT_VER}"
CATALINA_HOME="${SCRIPT_DIR}/${TOMCAT_DIR}"
CATALINA_BIN="${CATALINA_HOME}/bin"
CATALINA_STARTUP="${CATALINA_BIN}/startup.sh"
CATALINA_CTL="${CATALINA_BIN}/catalina.sh"
CATALINA_WEBAPPS="${CATALINA_HOME}/webapps"

# ── Locate JDK ────────────────────────────────────────────────────────────────
export JAVA_HOME="${SCRIPT_DIR}/jdk-25"
export JRE_HOME="${JAVA_HOME}"
log_step "[1/4] Checking JDK installation..."
if [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
    log_error "ERROR: JDK not found at ${JAVA_HOME} - run deploy.sh first."
    exit 1
fi
log_ok "[1/4] JDK found."

# ── Locate Tomcat ─────────────────────────────────────────────────────────────
log_step "[2/4] Checking Tomcat installation..."
if [[ ! -d "${CATALINA_HOME}" ]]; then
    log_error "ERROR: ${TOMCAT_DIR} not found - run deploy.sh first."
    exit 1
fi
if [[ ! -x "${CATALINA_STARTUP}" ]]; then
    log_error "ERROR: Tomcat startup script missing at ${CATALINA_STARTUP}."
    exit 1
fi
if [[ ! -x "${CATALINA_CTL}" ]]; then
    log_error "ERROR: Tomcat control script missing at ${CATALINA_CTL}."
    exit 1
fi
if [[ ! -d "${CATALINA_WEBAPPS}" ]]; then
    log_error "ERROR: Tomcat webapps directory missing at ${CATALINA_WEBAPPS}."
    exit 1
fi
log_ok "[2/4] Tomcat found."

log_info "Using JAVA_HOME=${JAVA_HOME}"
log_info "Using JRE_HOME=${JRE_HOME}"
log_info "Using Tomcat: ${TOMCAT_DIR}"

export CATALINA_HOME
log_step "[3/4] Refreshing WAR deployments..."
refresh_war "SyncLite Consolidator" "synclite-consolidator" \
    "../lib/consolidator/synclite-consolidator-*.war" \
    "../target/synclite-platform-oss/lib/consolidator/synclite-consolidator-*.war" \
    "../synclite-consolidator/root/web/target/synclite-consolidator-*.war" \
    "../synclite-consolidator/root/web/target/*.war"
refresh_war "SyncLite Sample App" "synclite-sample-app" \
    "../sample-apps/synclite-logger/jsp-servlet/web/target/*.war" \
    "../synclite-sample-web-app/web/target/*.war"
refresh_war "SyncLite DB" "synclite-db" \
    "../tools/synclite-db/*.war" \
    "../target/synclite-platform-oss/tools/synclite-db/*.war" \
    "../synclite-db/root/web/target/synclite-db-*.war" \
    "../synclite-db/root/web/target/*.war"
refresh_war "SyncLite DBReader" "synclite-dbreader" \
    "../tools/synclite-dbreader/*.war" \
    "../target/synclite-platform-oss/tools/synclite-dbreader/*.war" \
    "../synclite-dbreader/root/web/target/synclite-dbreader-*.war" \
    "../synclite-dbreader/root/web/target/*.war"
refresh_war "SyncLite QReader" "synclite-qreader" \
    "../tools/synclite-qreader/*.war" \
    "../target/synclite-platform-oss/tools/synclite-qreader/*.war" \
    "../synclite-qreader/root/web/target/synclite-qreader-*.war" \
    "../synclite-qreader/root/web/target/*.war"
refresh_war "SyncLite Job Monitor" "synclite-jobmonitor" \
    "../tools/synclite-jobmonitor/*.war" \
    "../target/synclite-platform-oss/tools/synclite-jobmonitor/*.war" \
    "../synclite-job-monitor/root/web/target/synclite-jobmonitor-*.war" \
    "../synclite-job-monitor/root/web/target/*.war"
log_ok "[3/4] WAR refresh completed."

log_step "[4/4] Starting Tomcat..."
"${CATALINA_STARTUP}"
log_ok "[4/4] Tomcat startup command completed."
echo
log_ok "Start script finished."

