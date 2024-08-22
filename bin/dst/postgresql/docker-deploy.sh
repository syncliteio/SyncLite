#!/usr/bin/env bash

DST_USER=synclite
DST_USER_PASSWORD=synclite
DST_DB_NAME=synclitedb
JOB_NAME=job1

mkdir -p $HOME/synclite/${JOB_NAME}/dstDir/postgresql/data

echo -e "\n=====Deploying synclite-dst-postgresql docker container=====\n"
docker build \
	--build-arg DST_USER=${DST_USER} \
	--build-arg DST_USER_PASSWORD=${DST_USER_PASSWORD} \
	--build-arg DST_DB_NAME=${DST_DB_NAME} \
	-t synclite-dst-postgresql .
