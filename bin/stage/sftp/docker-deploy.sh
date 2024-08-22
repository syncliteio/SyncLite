#!/usr/bin/env bash

UPLOAD_USER=synclite
UPLOAD_USER_PASSWORD=synclite
STAGE_DIR_NAME=stageDir
JOB_NAME=job1

mkdir -p $HOME/synclite/${JOB_NAME}/stageDir

echo -e "\n=====Deploying synclite-stage-sftp-server docker container=====\n"
docker build \
	--build-arg UPLOAD_USER=${UPLOAD_USER} \
	--build-arg UPLOAD_USER_PASSWORD=${UPLOAD_USER_PASSWORD} \
	--build-arg STAGE_DIR_NAME=${STAGE_DIR_NAME} \
	-t synclite-stage-sftp-server .
