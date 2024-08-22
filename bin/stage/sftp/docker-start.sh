#!/usr/bin/env bash

HOST_IP_ADDRESS=$(hostname -I | cut -d' ' -f1)
PORT=55555
UPLOAD_USER=synclite
UPLOAD_USER_PASSWORD=synclite
STAGE_DIR_NAME=stageDir
JOB_NAME=job1

echo -e "\n=====Starting synclite-stage-sftp-server docker container=====\n"

docker run \
	-d \
	-p ${PORT}:22 \
	-v $HOME/synclite/${JOB_NAME}/stageDir:/var/uploads/${STAGE_DIR_NAME} \
	--name synclite-stage-sftp-server \
	synclite-stage-sftp-server

echo "#==============WARNINGS====================================================================="
echo "#1. Default upload username/password is synclite/synclite. Change username/password in docker-deploy.sh and docker-start.sh scripts."
echo "#2. Setup additional security machanisms as needed."
echo "#==========================================================================================="
echo ""
echo "#==============SFTP Configuration to use in synclite_logger.conf for SyncLite applications=="
echo "#sftp:destination-type=SFTP"
echo "#sftp:host=${HOST_IP_ADDRESS}"
echo "#sftp:port=${PORT}"
echo "#sftp:user-name=${UPLOAD_USER}"
echo "#sftp:password=${UPLOAD_USER_PASSWORD}"
echo "#sftp:remote-stage-directory=/${STAGE_DIR_NAME}"
echo "#==========================================================================================="
