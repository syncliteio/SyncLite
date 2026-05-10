#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Change to the directory containing this script
cd "$(cd "$(dirname "$0")" && pwd)"

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

copy_war() {
	local source_pattern="$1"
	local target_path="$2"
	local label="$3"
	local matches=( ${source_pattern} )

	if (( ${#matches[@]} == 0 )); then
		log_error "ERROR: ${label} WAR not found: ${source_pattern}"
		exit 1
	fi

	log_info "  - Deploying ${label} WAR from ${matches[0]}"
	cp -f "${matches[0]}" "${target_path}"
	log_ok "  - ${label} WAR deployed."
}

log_info "========================================"
log_info "SyncLite Platform Deploy"
log_info "========================================"
echo

# ── Versions ──────────────────────────────────────────────────────────────────
TOMCAT_VER="9.0.117"
JDK_VER="25"
TOMCAT_DIR="apache-tomcat-${TOMCAT_VER}"
JDK_DIR="jdk-${JDK_VER}"

is_tomcat_ready() {
	[[ -f "${TOMCAT_DIR}/conf/server.xml" && -f "${TOMCAT_DIR}/bin/catalina.sh" ]]
}

is_jdk_ready() {
	[[ -x "${JDK_DIR}/bin/java" ]]
}

# ── Download and extract Tomcat ───────────────────────────────────────────────
TOMCAT_TGZ="apache-tomcat-${TOMCAT_VER}.tar.gz"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VER}/bin/${TOMCAT_TGZ}"

if is_tomcat_ready; then
	log_ok "[1/7] Reusing existing Apache Tomcat ${TOMCAT_VER}."
	log_ok "[2/7] Tomcat extraction skipped (existing installation is healthy)."
else
	if [[ -f "${TOMCAT_TGZ}" ]]; then
		log_ok "[1/7] Reusing downloaded Apache Tomcat archive ${TOMCAT_TGZ}."
	else
		log_step "[1/7] Downloading Apache Tomcat ${TOMCAT_VER}..."
		curl -fsSL -o "${TOMCAT_TGZ}" "${TOMCAT_URL}"
		log_ok "[1/7] Tomcat download complete."
	fi

	log_step "[2/7] Extracting Apache Tomcat..."
	rm -rf "${TOMCAT_DIR}"
	tar -xzf "${TOMCAT_TGZ}"
	log_ok "[2/7] Tomcat extraction complete."
fi

log_step "[3/7] Configuring Tomcat users..."
cp -f tomcat-users.xml "${TOMCAT_DIR}/conf/tomcat-users.xml"
chmod +x "${TOMCAT_DIR}/bin/"*.sh
log_ok "[3/7] Tomcat user configuration complete."

# ── Download and extract OpenJDK 25 (Eclipse Temurin) ─────────────────────────
JDK_TGZ="openjdk-${JDK_VER}-linux-x64.tar.gz"
JDK_URL="https://api.adoptium.net/v3/binary/latest/${JDK_VER}/ga/linux/x64/jdk/hotspot/normal/eclipse"

if is_jdk_ready; then
	log_ok "[4/7] Reusing existing OpenJDK ${JDK_VER}."
	log_ok "[5/7] OpenJDK extraction skipped (existing installation is healthy)."
	log_ok "[6/7] JDK installation already complete."
else
	if [[ -f "${JDK_TGZ}" ]]; then
		log_ok "[4/7] Reusing downloaded OpenJDK archive ${JDK_TGZ}."
	else
		log_step "[4/7] Downloading OpenJDK ${JDK_VER}..."
		curl -fsSL -o "${JDK_TGZ}" "${JDK_URL}"
		log_ok "[4/7] OpenJDK download complete."
	fi

	log_step "[5/7] Extracting OpenJDK ${JDK_VER}..."
	rm -rf jdk_tmp
	mkdir -p jdk_tmp
	tar -xzf "${JDK_TGZ}" -C jdk_tmp
	log_ok "[5/7] OpenJDK extraction complete."

	# Rename extracted folder to a stable name (jdk-25)
	log_step "[6/7] Finalizing JDK installation..."
	if [[ -e "${JDK_DIR}" ]]; then
		rm -rf "${JDK_DIR}" || {
			log_error "ERROR: Failed to remove existing ${JDK_DIR}. Close any process using it and retry."
			exit 1
		}
		if [[ -e "${JDK_DIR}" ]]; then
			log_error "ERROR: Failed to remove existing ${JDK_DIR}. Close any process using it and retry."
			exit 1
		fi
	fi

	jdk_candidates=(jdk_tmp/jdk-*)
	if (( ${#jdk_candidates[@]} == 0 )); then
		log_error "ERROR: Extracted JDK folder was not found under jdk_tmp."
		exit 1
	fi

	JDK_SRC="${jdk_candidates[0]}"
	if ! mv "${JDK_SRC}" "${JDK_DIR}"; then
		# Fallback when move fails due permissions/locks/cross-device boundaries.
		mkdir -p "${JDK_DIR}"
		cp -a "${JDK_SRC}/." "${JDK_DIR}/" || {
			log_error "ERROR: Failed to finalize JDK folder from ${JDK_SRC} to ${JDK_DIR}."
			exit 1
		}
	fi
	rm -rf jdk_tmp

	if [[ ! -x "${JDK_DIR}/bin/java" ]]; then
		log_error "ERROR: JDK setup failed. Missing ${JDK_DIR}/bin/java"
		exit 1
	fi
	log_ok "[6/7] JDK installation complete."
fi

if [[ ! -x "${JDK_DIR}/bin/java" ]]; then
	log_error "ERROR: JDK setup failed. Missing ${JDK_DIR}/bin/java"
	exit 1
fi

# ── Deploy WAR files ──────────────────────────────────────────────────────────
WEBAPPS="apache-tomcat-${TOMCAT_VER}/webapps"
log_step "[7/7] Deploying WAR files to Tomcat..."
copy_war "../lib/consolidator/synclite-consolidator-*.war" "${WEBAPPS}/synclite-consolidator.war" "SyncLite Consolidator"
copy_war "../sample-apps/synclite-logger/jsp-servlet/web/target/*.war" "${WEBAPPS}/synclite-sample-app.war" "SyncLite Sample App"
copy_war "../tools/synclite-db/*.war" "${WEBAPPS}/synclite-db.war" "SyncLite DB"
copy_war "../tools/synclite-dbreader/*.war" "${WEBAPPS}/synclite-dbreader.war" "SyncLite DBReader"
copy_war "../tools/synclite-qreader/*.war" "${WEBAPPS}/synclite-qreader.war" "SyncLite QReader"
copy_war "../tools/synclite-jobmonitor/*.war" "${WEBAPPS}/synclite-jobmonitor.war" "SyncLite Job Monitor"
log_ok "[7/7] WAR deployment complete."

echo
log_ok "Deploy complete. Tomcat and JDK are ready under $(pwd)."

