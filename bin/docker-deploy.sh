#!/usr/bin/env bash

#Set STAGE to SFTP/MINIO if you need a docker container for stage to be deployed too
STAGE=""

#Set DST to POSTGRESQL/MYSQL if you need a docker conainer for destination to be deployed too.
DST=""

# Get the path of the parent directory
script_dir=$(dirname "$(readlink -f "$0")")
parent_directory=$(dirname "$script_dir")

# Define the output archive path
archive_path="synclite-platform.tar.gz"

# Delete existing tar file
rm -rf "$archive_path"

# Create the tar archive
tar -czf "$archive_path" -C "$parent_directory" .

echo -e "\n=======Deploying synclite-consolidator docker container=====\n"
docker build -t synclite-consolidator .

rm -rf "$archive_path"

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

