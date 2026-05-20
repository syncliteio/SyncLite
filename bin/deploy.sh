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

log_warn() {
	printf "%b\n" "${YELLOW}$1${RESET}"
}

require_tool() {
	local tool="$1"
	local label="$2"
	if ! command -v "${tool}" >/dev/null 2>&1; then
		log_error "ERROR: Required tool not found for ${label}: ${tool}"
		exit 1
	fi
}

download_file() {
	local url="$1"
	local out="$2"

	if command -v curl >/dev/null 2>&1; then
		curl -fL --progress-bar -o "${out}" "${url}"
		return
	fi

	if command -v wget >/dev/null 2>&1; then
		wget --progress=bar:force:noscroll -O "${out}" "${url}"
		return
	fi

	log_error "ERROR: No supported download tool found (curl or wget)."
	exit 1
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

copy_war() {
	local label="$1"
	local target_path="$2"
	shift 2
	local source_path

	if ! source_path="$(resolve_war "$@")"; then
		log_error "ERROR: ${label} WAR not found in packaged or module build output."
		exit 1
	fi

	log_info "  - Deploying ${label} WAR from ${source_path}"
	cp -f "${source_path}" "${target_path}"
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

require_tool tar "archive extraction"

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
		download_file "${TOMCAT_URL}" "${TOMCAT_TGZ}"
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
		download_file "${JDK_URL}" "${JDK_TGZ}"
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
copy_war "SyncLite Consolidator" "${WEBAPPS}/synclite-consolidator.war" \
	"../lib/consolidator/synclite-consolidator-*.war" \
	"../target/synclite-platform-oss/lib/consolidator/synclite-consolidator-*.war" \
	"../synclite-consolidator/root/web/target/synclite-consolidator-*.war" \
	"../synclite-consolidator/root/web/target/*.war"
copy_war "SyncLite Sample App" "${WEBAPPS}/synclite-sample-app.war" \
	"../sample-apps/synclite-logger/jsp-servlet/web/target/*.war" \
	"../synclite-sample-web-app/web/target/*.war"
copy_war "SyncLite DB" "${WEBAPPS}/synclite-db.war" \
	"../tools/synclite-db/*.war" \
	"../target/synclite-platform-oss/tools/synclite-db/*.war" \
	"../synclite-db/root/web/target/synclite-db-*.war" \
	"../synclite-db/root/web/target/*.war"
copy_war "SyncLite DBReader" "${WEBAPPS}/synclite-dbreader.war" \
	"../tools/synclite-dbreader/*.war" \
	"../target/synclite-platform-oss/tools/synclite-dbreader/*.war" \
	"../synclite-dbreader/root/web/target/synclite-dbreader-*.war" \
	"../synclite-dbreader/root/web/target/*.war"
copy_war "SyncLite QReader" "${WEBAPPS}/synclite-qreader.war" \
	"../tools/synclite-qreader/*.war" \
	"../target/synclite-platform-oss/tools/synclite-qreader/*.war" \
	"../synclite-qreader/root/web/target/synclite-qreader-*.war" \
	"../synclite-qreader/root/web/target/*.war"
copy_war "SyncLite Job Monitor" "${WEBAPPS}/synclite-jobmonitor.war" \
	"../tools/synclite-jobmonitor/*.war" \
	"../target/synclite-platform-oss/tools/synclite-jobmonitor/*.war" \
	"../synclite-job-monitor/root/web/target/synclite-jobmonitor-*.war" \
	"../synclite-job-monitor/root/web/target/*.war"
log_ok "[7/7] WAR deployment complete."

echo
log_ok "Deploy complete. Tomcat and JDK are ready under $(pwd)."

