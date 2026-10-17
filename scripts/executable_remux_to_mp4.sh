#!/bin/bash
for file in "$@"; do
	ffmpeg -y -i "$file" -acodec copy -vcodec copy "${file%.*}.mp4"
done
notify-send Remuxing done
