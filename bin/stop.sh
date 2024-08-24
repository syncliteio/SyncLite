#!/usr/bin/env bash

PARENT_DIR="$(cd "$(dirname "$0")" && pwd)"

export JAVA_HOME="$PARENT_DIR/jdk-11"

# Function to find and kill process by name using ps -eaf
kill_process_by_name() {
  local process_name=$1
  local pid

  pid=$(ps -eaf | grep "$process_name" | grep -v grep | awk '{print $2}')
  if [[ -n $pid && $pid =~ ^[0-9]+$ ]]; then
    kill -9 "$pid"
    echo "Killed process $pid ($process_name)"
  else
    echo "No valid process found for $process_name"
  fi
}

# Kill the Java processes
kill_process_by_name "com.synclite.consolidator.Main"
kill_process_by_name "com.synclite.dbreader.Main"
kill_process_by_name "com.synclite.qreader.Main"
kill_process_by_name "org.apache.catalina.startup.Bootstrap"

