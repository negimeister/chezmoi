#!/bin/bash

VARS=$(efivar -l)

for var in $VARS; do
    efivar -p -n $var
done
