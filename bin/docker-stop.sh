#!/usr/bin/env bash

#Set STAGE to SFTP/MINIO if you need a docker container for stage to be deployed too
STAGE=""

#Set DST to POSTGRESQL/MYSQL if you need a docker conainer for destination to be deployed too.
DST=""

script_dir=$(dirname "$(readlink -f "$0")")

echo -e "\n=======Stopping and removing synclite-consolidator docker container=====\n"

docker stop synclite-consolidator
docker rm synclite-consolidator

if [ "$STAGE" = "SFTP" ]; then
    cd "$script_dir/stage/sftp"
    ./docker-stop.sh
elif [ "$STAGE" = "MINIO" ]; then
    cd "$script_dir/stage/minio"
    ./docker-stop.sh
fi

if [ "$DST" = "POSTGRESQL" ]; then
    cd "$script_dir/dst/postgresql"
    ./docker-stop.sh
elif [ "$DST" = "MYSQL" ]; then
    cd "$script_dir/dst/mysql"
    ./docker-stop.sh
fi

cd "$script_dir"

