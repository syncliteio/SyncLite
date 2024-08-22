#!/usr/bin/env bash


echo -e "\n=====Stopping synclite-stage-minio-server docker container=====\n"

docker stop synclite-stage-minio-server
docker rm synclite-stage-minio-server
