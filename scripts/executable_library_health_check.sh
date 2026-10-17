#!/bin/bash
FLAC_DIR=$HOME/audio/dj
STEM_DIR=$HOME/audio/stems
TRACK_PATTERN="track-[0-9|a-Z]*\.flac"
STEM_PATTERN="track-[0-9|a-Z]*\.mp4"
echo "[Checking track naming]"
find $FLAC_DIR -type f -not -iname "$TRACK_PATTERN" | grep -v .m3u8
find $STEM_DIR -type f -not -iname "$STEM_PATTERN" | grep -v .m3u8

echo "[Checking stems]"
for file in $(find $FLAC_DIR -type f -iname "$TRACK_PATTERN" -newermt 2025-05-30); do
	BASENAME=$(basename $file)
	ID="${BASENAME%.*}"
	STEM=$STEM_DIR/$ID.mp4
	if [ ! -f $STEM ]; then
		echo "no stem file for $file"
	fi
done
