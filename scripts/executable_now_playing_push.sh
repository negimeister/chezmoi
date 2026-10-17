#!/bin/bash
set -o pipefail
while true; do
  curl -f "$1" | curl -X POST "$2" -H "Content-Type: application/json"  -d @-
  sleep 5
done
