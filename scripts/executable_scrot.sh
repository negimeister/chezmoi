#!/bin/bash
mkdir -p ~/screenshots
cd ~/screenshots
scrot -a $(slop -f "%x,%y,%w,%h")
