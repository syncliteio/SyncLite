#!/usr/bin/env bash


echo -e "\n=====Stopping and removing synclite-stage-sftp-server docker container=====\n"

docker stop synclite-stage-sftp-server
docker rm synclite-stage-sftp-server
