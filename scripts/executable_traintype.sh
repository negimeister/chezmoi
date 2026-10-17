#!/bin/bash
set -x
#UIC=`echo "$1" | sed 's/[ -]//g' | xargs`
UIC=`echo "$1" | xargs`
echo "UIC $UIC"
cat vehicletypes.json | jq ".[] | select(.objekt==\"$UIC\") | .fahrzeug_typ " | xclip -selection clipboard
#cat missing.json | grep $UIC
echo $(xclip -selection clipboard -o)
