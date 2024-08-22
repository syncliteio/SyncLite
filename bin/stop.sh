#!/usr/bin/env bash

pid=$("$JAVA_HOME/bin/jps" -l | grep com.synclite.consolidator.Main | awk '{print $1}')
if [[ -n $pid ]]; then
  kill "$pid"
fi

pid=$("$JAVA_HOME/bin/jps" -l | grep org.apache.catalina.startup.Bootstrap | awk '{print $1}')
if [[ -n $pid ]]; then
  kill "$pid"
fi
