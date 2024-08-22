#!/usr/bin/env bash


HOST_IP_ADDRESS=$(hostname -I | cut -d' ' -f1)
ENABLE_HTTPS=false
JOB_NAME=job1

mkdir -p $HOME/synclite/${JOB_NAME}/stageDir

echo -e "\n=====Deploying synclite-stage-minio-server docker container=====\n"

docker build \
	--build-arg MINIO_ROOT_USER=synclite_root \
	--build-arg MINIO_ROOT_PASSWORD=synclite \
	--build-arg UPLOAD_USER=synclite \
	--build-arg UPLOAD_USER_PASSWORD=synclite \
	--build-arg DOWNLOAD_USER=synclite_consolidator \
	--build-arg DOWNLOAD_USER_PASSWORD=synclite \
	--build-arg HOST_IP_ADDRESS=${HOST_IP_ADDRESS} \
	--build-arg ENABLE_HTTPS=${ENABLE_HTTPS} \
	-t synclite-stage-minio-server .
