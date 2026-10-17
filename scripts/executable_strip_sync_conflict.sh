#!/bin/bash
echo $1 | sed -E 's/sync-conflict-[A-Z,a-z,0-9,-]*\.//g'
