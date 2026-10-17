#!/bin/bash
cat $(find /tmp -name "overviewCache*" -printf '%T@ %p\n' 2>/dev/null  | sort -n | tail -1 | cut -f2- -d" ") | jq | less
