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

log_warn() {
    printf "%b\n" "${YELLOW}$1${RESET}"
}

log_info "========================================"
log_info "SyncLite Platform Stop"
log_info "========================================"
echo

export JAVA_HOME="${SCRIPT_DIR}/jdk-25"
TOMCAT_VER="9.0.117"
TOMCAT_DIR="apache-tomcat-${TOMCAT_VER}"

# ── Graceful Tomcat shutdown ──────────────────────────────────────────────────────
log_step "[1/3] Requesting Tomcat shutdown..."
if [[ -x "${TOMCAT_DIR}/bin/shutdown.sh" ]]; then
    log_info "Attempting graceful Tomcat shutdown..."
    export CATALINA_HOME="${SCRIPT_DIR}/${TOMCAT_DIR}"
    "${CATALINA_HOME}/bin/shutdown.sh" || true
    log_ok "[1/3] Shutdown signal sent to Tomcat."
else
    log_warn "[1/3] Tomcat shutdown script not found. Skipping graceful shutdown."
fi

# ── Kill any remaining Java processes by class name ──────────────────────────────
kill_by_class() {
    local classname="$1"
    local pids
    pids=$(pgrep -f "${classname}" 2>/dev/null || true)
    if [[ -n "${pids}" ]]; then
        log_info "Stopping ${classname} (PID ${pids})..."
        kill -15 ${pids} 2>/dev/null || true
        sleep 2
        # Force kill if still running
        pids=$(pgrep -f "${classname}" 2>/dev/null || true)
        [[ -n "${pids}" ]] && kill -9 ${pids} 2>/dev/null || true
    fi
}

log_step "[2/3] Stopping remaining SyncLite and Tomcat Java processes..."
kill_by_class "com.synclite.consolidator.Main"
kill_by_class "com.synclite.dbreader.Main"
kill_by_class "com.synclite.qreader.Main"
kill_by_class "org.apache.catalina.startup.Bootstrap"
log_ok "[2/3] Process termination pass complete."

log_step "[3/3] Finalizing stop workflow..."
log_ok "[3/3] Stop workflow complete."
echo
log_ok "Stop script finished."

