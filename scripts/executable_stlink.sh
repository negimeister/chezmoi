#!/bin/bash

until st-flash --reset write "$1" 0x8000000; do true;  done
