#!/bin/bash
find . -type f \( -iname "*.m4a" \! -iname "*.m4a.m4a" \) -print -exec ffmpeg -i {} -acodec copy -vcodec copy {}.m4a \; -exec rm {} \;
