#!/usr/bin/env bash

mkdir -p ${HOME}/synclite/demo/stageDir 

HOST_IP_ADDRESS=$(hostname -I | cut -d' ' -f1)
MINIO_ROOT_USER=synclite_root
MINIO_ROOT_PASSWORD=synclite
BUCKET_NAME=synclite-devices
UPLOAD_USER=synclite
UPLOAD_USER_PASSWORD=synclite
DOWNLOAD_USER=synclite_consolidator
DOWNLOAD_USER_PASSWORD=synclite
ENABLE_HTTPS=false
JOB_NAME=job1

if [ "$ENABLE_HTTPS" = "true" ]; then
    ENDPOINT="https://$HOST_IP_ADDRESS:9000"
else
    ENDPOINT="http://$HOST_IP_ADDRESS:9000"
fi

echo -e "\n=====Starting synclite-stage-minio-server docker container=====\n"

docker run \
   -p 9000:9000 \
   -p 9090:9090 \
   -d \
   --name synclite-stage-minio-server \
   -e "MINIO_ROOT_USER=synclite_root" \
   -e "MINIO_ROOT_PASSWORD=synclite_root" \
   -e "BUCKET_NAME=synclite-devices" \
   -e "HOST_IP_ADDRESS=${HOST_IP_ADDRESS}" \
   -v ${HOME}/synclite/${JOB_NAME}/stageDir:/data \
   synclite-stage-minio-server sh -c "/usr/bin/setup.sh && tail -f /dev/null"

echo "#==============WARNINGS====================================================================="
echo "#1. Default MinIO root username/password is synclite_root/synclite. Change username/password in docker-deploy.sh and docker-start.sh scripts."
echo "#2. Default upload username/password is synclite/synclite. Change username/password in docker-deploy.sh and docker-start.sh scripts."
echo "#3. Default download username/password is synclite_consolidator/synclite. Change username/password in docker-deploy.sh and docker-start.sh scripts."
echo "#4. For upload user and download users, it is strongly recommended to open the MinIO console at http://localhost:9000 and create new access-key and secret-key for these users and use them in the SyncLite apps and SyncLite consolidator instead of directly using the user credentials."
echo "#5. Setup additional security machanisms as needed."
echo "#==========================================================================================="
echo ""
echo "#==============MinIO Configuration to use in synclite_logger.conf for SyncLite applications=="
echo "#minio:endpoint=${ENDPOINT}"
echo "#minio:bucket-name=${BUCKET_NAME}"
echo "#minio:access-key=${UPLOAD_USER}"
echo "#minio:secret-key=${UPLOAD_USER_PASSWORD}"

echo "#==========================================================================================="
