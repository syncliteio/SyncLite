#!/usr/bin/env bash

#Set STAGE to SFTP/MINIO if you need a docker container for stage to be deployed too
STAGE=""

#Set DST to POSTGRESQL/MYSQL if you need a docker conainer for destination to be deployed too.
DST=""

#Set JOB_NAME to different job names if you need to maintain and run multiple jobs on the same host.
JOB_NAME=job1

script_dir=$(dirname "$(readlink -f "$0")")
mkdir -p "$HOME"/synclite/${JOB_NAME}/workDir
mkdir -p "$HOME"/synclite/${JOB_NAME}/stageDir

echo -e "\n=====Starting synclite-consolidator docker container=====\n"
docker run \
    -p 8080:8080 \
    -v "$HOME"/synclite:/home/root/synclite \
    --net=host \
    -d \
    --name synclite-consolidator \
    -e "JAVA_TOOL_OPTIONS=-Duser.home=/home/root" \
    synclite-consolidator:latest sh -c "./start.sh && tail -f /dev/null"

if [ "$STAGE" = "SFTP" ]; then
    cd "$script_dir/stage/sftp"
    ./docker-start.sh
elif [ "$STAGE" = "MINIO" ]; then
    cd "$script_dir/stage/minio"
    ./docker-start.sh
fi

if [ "$DST" = "POSTGRESQL" ]; then
    cd "$script_dir/dst/postgresql"
    ./docker-start.sh
elif [ "$DST" = "MYSQL" ]; then
    cd "$script_dir/dst/mysql"
    ./docker-start.sh
fi

cd "$script_dir"

echo -e "\n=======Started docker containers========================\n"

docker ps
