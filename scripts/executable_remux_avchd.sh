#!/bin/bash
for file in "$@"; do
	ffmpeg -y -i "$file" -acodec copy -vcodec copy -c:s copy "$file.mkv"
done
notify-send Remuxing done
