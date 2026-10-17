#!/bin/bash
find . -name "*sync-conflict*" -print0 | while read -d $'\0' file
do
  base=$(strip_sync_conflict.sh "$file")
  echo $base
  diff --side-by-side "$base" "$file"
done
