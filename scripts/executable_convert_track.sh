#!/bin/bash
set -euo pipefail

# Convert the file to FLAC
ffmpeg -hide_banner -loglevel error -i "$1" -map_metadata 0 "${1%.*}.flac"
mkdir -p /tmp/music_imported
mv "$1" /tmp/music_imported
