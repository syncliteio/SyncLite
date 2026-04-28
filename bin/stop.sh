#!/usr/bin/env bash

# Change to the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

export JAVA_HOME="${SCRIPT_DIR}/jdk-25"
TOMCAT_VER="9.0.117"
TOMCAT_DIR="apache-tomcat-${TOMCAT_VER}"

# ── Graceful Tomcat shutdown ──────────────────────────────────────────────────────
if [[ -x "${TOMCAT_DIR}/bin/shutdown.sh" ]]; then
    echo "Shutting down Tomcat gracefully..."
    export CATALINA_HOME="${SCRIPT_DIR}/${TOMCAT_DIR}"
    "${CATALINA_HOME}/bin/shutdown.sh" || true
fi

# ── Kill any remaining Java processes by class name ──────────────────────────────
kill_by_class() {
    local classname="$1"
    local pids
    pids=$(pgrep -f "${classname}" 2>/dev/null || true)
    if [[ -n "${pids}" ]]; then
        echo "Stopping ${classname} (PID ${pids})..."
        kill -15 ${pids} 2>/dev/null || true
        sleep 2
        # Force kill if still running
        pids=$(pgrep -f "${classname}" 2>/dev/null || true)
        [[ -n "${pids}" ]] && kill -9 ${pids} 2>/dev/null || true
    fi
}

kill_by_class "com.synclite.consolidator.Main"
kill_by_class "com.synclite.dbreader.Main"
kill_by_class "com.synclite.qreader.Main"
kill_by_class "org.apache.catalina.startup.Bootstrap"

echo "Done."

