#!/usr/bin/env bash

DST_USER=synclite
DST_USER_PASSWORD=synclite
DST_DB_NAME=synclitedb
JOB_NAME=job1

mkdir -p $HOME/synclite/${JOB_NAME}/dstDir/postgresql/data

echo -e "\n=====Starting synclite-dst-postgresql docker container=====\n"
docker run \
	-d \
	-p 5432:5432 \
	--name synclite-dst-postgresql \
	-v $HOME/synclite/${JOB_NAME}/dstDir/postgresql/data:/var/lib/postgresql/data \
	synclite-dst-postgresql

echo "#==============WARNINGS====================================================================="
echo "#1. Default upload username/password is synclite/synclite. Change username/password in docker-deploy.sh and docker-start.sh scripts."
echo "#2. Setup additional security machanisms as needed."
echo "#==========================================================================================="
echo ""
echo "#==========JDBC Connection String to specify in SyncLite Consolidator Job Configuration===="
echo "jdbc:postgresql://127.0.0.1:5432/${DST_DB_NAME}?user=${DST_USER}?password=${DST_USER_PASSWORD}"
echo "#==========================================================================================="
echo ""
echo "#==========psql command to connect to this postgresql db===================================="
echo "psql -h localhost -p 5432 -U ${DST_USER} -d $DST_DB_NAME"
echo "#==========================================================================================="
