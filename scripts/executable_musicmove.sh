#!/bin/bash
set -x
newname=$(musicname.sh "$1")
mv --no-clobber "$1" "$newname"
