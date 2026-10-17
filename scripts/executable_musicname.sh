#!/bin/bash
#set -x
extension="${1##*.}"
fp=$(fpcalc "$1")
hash="$(echo $fp | sha256sum | head -c 64)"
echo "moved-$hash.$extension"
