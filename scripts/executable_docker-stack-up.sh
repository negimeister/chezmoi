#!/bin/bash
set -e
FILES=""
for A in $(ls ~/docker/*yml); do
  FILES+="-f $A "
done
docker-compose $FILES up -d
#find ~/docker -iname "*.yml" -exec docker-compose -f {} up -d \;
