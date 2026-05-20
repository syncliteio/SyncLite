#!/usr/bin/env bash
set -euo pipefail

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

require_tool() {
    local tool="$1"
    local label="$2"
    if ! command -v "${tool}" >/dev/null 2>&1; then
        log_error "ERROR: Required tool not found for ${label}: ${tool}"
        exit 1
    fi
}

#Set STAGE to SFTP/MINIO if you need a docker container for stage to be deployed too
STAGE=""

#Set DST to POSTGRESQL/MYSQL if you need a docker conainer for destination to be deployed too.
DST=""

# Get the path of the parent directory
script_dir="$(cd "$(dirname "$0")" && pwd)"
parent_directory=$(dirname "$script_dir")
cd "$script_dir"

log_info "========================================"
log_info "SyncLite Platform Docker Deploy"
log_info "========================================"
echo

require_tool tar "docker deployment packaging"

# Define the output archive path
archive_path="synclite-platform.tar.gz"

# Delete existing tar file
rm -f "$archive_path"

# Create the tar archive, excluding the archive itself to avoid tar warnings
log_step "[1/4] Packaging SyncLite platform archive..."
tar -czf "$archive_path" --exclude="./bin/$archive_path" -C "$parent_directory" .
log_ok "[1/4] Platform archive created."

docker_cmd="docker"
if ! docker info >/dev/null 2>&1; then
    if sudo -n docker info >/dev/null 2>&1; then
        docker_cmd="sudo docker"
    else
        log_error "ERROR: Docker daemon is not reachable for the current user."
        log_info "Run one of the following and retry:"
        log_info "  sudo usermod -aG docker \$USER && newgrp docker"
        log_info "  or run this script with sudo"
        exit 1
    fi
fi

log_step "[2/4] Building synclite-consolidator Docker image..."
$docker_cmd build -t synclite-consolidator .
log_ok "[2/4] Docker image build completed."

rm -f "$archive_path"

log_step "[3/4] Deploying optional stage services..."
if [ "$STAGE" = "SFTP" ]; then
    cd "$script_dir/stage/sftp"
    ./docker-deploy.sh
elif [ "$STAGE" = "MINIO" ]; then
    cd "$script_dir/stage/minio"
    ./docker-deploy.sh
fi
log_ok "[3/4] Stage service deployment step complete."

log_step "[4/4] Deploying optional destination services..."
if [ "$DST" = "POSTGRESQL" ]; then
    cd "$script_dir/dst/postgresql"
    ./docker-deploy.sh
elif [ "$DST" = "MYSQL" ]; then
    cd "$script_dir/dst/mysql"
    ./docker-deploy.sh
fi
log_ok "[4/4] Destination service deployment step complete."

cd "$script_dir"
echo
log_ok "Docker deployment finished successfully."

