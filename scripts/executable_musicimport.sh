#!/bin/bash
set -euo pipefail
# Constants
MUSIC_DIRECTORY="$HOME/audio/dj"

#ubscale.sh

# Unzip files in the current directory and subdirectories, then delete them
find . -type f -name "*.zip" -print0 | while IFS= read -r -d '' zip; do
    unzip -n "$zip" -d "$(dirname "$zip")" && rm "$zip"
done

# Check and convert music files in the current directory and subdirectories
find . -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.aac" -o -iname "*.m4a" -o -iname "*.ogg" \) -exec convert_track.sh "{}" \;

# Rename and move files with artist and title tags set, include FLAC files
find . -type f -iname "*.flac" -print0 -exec import_track.sh "{}" "$MUSIC_DIRECTORY" \;
