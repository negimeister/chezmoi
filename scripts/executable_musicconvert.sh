#!/bin/bash
set -euo pipefail
OLD="$(realpath $1)"
NEW="${OLD%.*}.flac"
ffmpeg -i "$OLD" "$NEW"
update_mixxx_path.py  "$OLD" "$NEW"
