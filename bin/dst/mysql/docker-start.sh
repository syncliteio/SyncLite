#!/usr/bin/env bash

ROOT_USER_PASSWORD=synclite
DST_USER=synclite
DST_USER_PASSWORD=synclite
DST_SCHEMA_NAME=syncliteschema
JOB_NAME=job1

mkdir -p $HOME/synclite/${JOB_NAME}/dstDir/mysql/data

echo -e "\n=====Starting synclite-dst-mysql docker container=====\n"

docker run -d \
    --name synclite-dst-mysql \
    -e MYSQL_ROOT_PASSWORD=${ROOT_USER_PASSWORD} \
    -e MYSQL_USER=${DST_USER} \
    -e MYSQL_PASSWORD=${DST_USER_PASSWORD} \
    -e MYSQL_DATABASE=${DST_SCHEMA_NAME} \
    -p 3306:3306 \
    -v $HOME/synclite/${JOB_NAME}/dstDir/mysql/data:/var/lib/mysql \
    synclite-dst-mysql

echo "#==============WARNINGS====================================================================="
echo "#1. Default upload username/password is synclite/synclite. Change username/password in docker-deploy.sh and docker-start.sh scripts."
echo "#2. Setup additional security machanisms as needed."
echo "#==========================================================================================="
echo ""
echo "#==========JDBC Connection String to specify in SyncLite Consolidator Job Configuration===="
echo "jdbc:mysql://127.0.0.1:5432/${DST_SCHEMA_NAME}?user=${DST_USER}?password=${DST_USER_PASSWORD}"
echo "#==========================================================================================="
echo ""
echo "#==========mysql client commandline to connect to this postgresql db===================================="
echo "mysql -h 127.0.0.1 -P 3306 -u ${DST_USER} -p ${DST_USER_PASSWORD}"
echo "#==========================================================================================="
