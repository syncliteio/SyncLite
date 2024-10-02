#!/usr/bin/env bash

# Get the absolute path of the parent directory
PARENT_DIR="$(cd "$(dirname "$0")" && pwd)"

export JAVA_HOME="$PARENT_DIR/jdk-11"

cd apache-tomcat-9.0.95/bin
./startup.sh

