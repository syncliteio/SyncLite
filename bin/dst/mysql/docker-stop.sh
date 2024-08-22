#!/usr/bin/env bash


echo -e "\n=====Stopping and removing synclite-dst-mysql docker container=====\n"

docker stop synclite-dst-mysql
docker rm synclite-dst-mysql
