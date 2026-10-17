#!/bin/bash

docker container rm $(docker container ls  -a -q --filter "ancestor=$1" --filter "status=exited")
