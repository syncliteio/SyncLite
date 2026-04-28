#!/usr/bin/env bash
set -euo pipefail

#Set STAGE to SFTP/MINIO if you need a docker container for stage to be deployed too
STAGE=""

#Set DST to POSTGRESQL/MYSQL if you need a docker conainer for destination to be deployed too.
DST=""

# Get the path of the parent directory
script_dir="$(cd "$(dirname "$0")" && pwd)"
parent_directory=$(dirname "$script_dir")
cd "$script_dir"

# Define the output archive path
archive_path="synclite-platform.tar.gz"

# Delete existing tar file
rm -f "$archive_path"

# Create the tar archive, excluding the archive itself to avoid tar warnings
tar -czf "$archive_path" --exclude="./bin/$archive_path" -C "$parent_directory" .

docker_cmd="docker"
if ! docker info >/dev/null 2>&1; then
    if sudo -n docker info >/dev/null 2>&1; then
        docker_cmd="sudo docker"
    else
        echo "ERROR: Docker daemon is not reachable for the current user."
        echo "Run one of the following and retry:"
        echo "  sudo usermod -aG docker \$USER && newgrp docker"
        echo "  or run this script with sudo"
        exit 1
    fi
fi

echo -e "\n=======Deploying synclite-consolidator docker container=====\n"
$docker_cmd build -t synclite-consolidator .

rm -f "$archive_path"

if [ "$STAGE" = "SFTP" ]; then
    cd "$script_dir/stage/sftp"
    ./docker-deploy.sh
elif [ "$STAGE" = "MINIO" ]; then
    cd "$script_dir/stage/minio"
    ./docker-deploy.sh
fi

if [ "$DST" = "POSTGRESQL" ]; then
    cd "$script_dir/dst/postgresql"
    ./docker-deploy.sh
elif [ "$DST" = "MYSQL" ]; then
    cd "$script_dir/dst/mysql"
    ./docker-deploy.sh
fi

cd "$script_dir"

