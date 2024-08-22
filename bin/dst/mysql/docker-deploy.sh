#!/usr/bin/env bash

DST_USER=synclite
DST_USER_PASSWORD=synclite
DST_SCHEMA_NAME=syncliteschema
JOB_NAME=job1

mkdir -p $HOME/synclite/${JOB_NAME}/dstDir/mysql/data

echo -e "\n=====Deploying synclite-dst-mysql docker container=====\n"
docker build \
	--build-arg DST_USER=${DST_USER} \
	--build-arg DST_USER_PASSWORD=${DST_USER_PASSWORD} \
	--build-arg DST_SCHEMA_NAME=${DST_SCHEMA_NAME} \
	-t synclite-dst-mysql .
