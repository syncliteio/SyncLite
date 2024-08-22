#!/usr/bin/env bash


echo -e "\n=====Stopping and removing synclite-dst-postgresql docker container=====\n"

docker stop synclite-dst-postgresql
docker rm synclite-dst-postgresql
