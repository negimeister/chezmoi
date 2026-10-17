#!/bin/bash
#ARTIST=$(zenity --entry --text="Producer")
#LOID=$(zenity --entry --text="Vocaloid")
#TITLE=$(zenity --entry --text="Title")
YTDL="yt-dlp --no-playlist"

echo "Artist:"
read ARTIST
echo "Vocaloid:"
read LOID
echo "Title:"
read TITLE
TARGETDIR=$(pwd)
TMPDIR=/tmp/$(uuidgen)
mkdir $TMPDIR
cd $TMPDIR
if  ! $YTDL -f bestaudio "$1"; then
    $YTDL "$1"
fi
INFILE=$(ls)
NAME="$ARTIST feat. $LOID - $TITLE"
if [[ "$INFILE" == *.webm ]];then
    OUTFILE="$NAME.opus"
    ffmpeg -i "$INFILE" -acodec copy -vn "$OUTFILE"
elif [[ "$INFILE" == *.mp4 ]]; then
    OUTFILE="$NAME.aac"
    ffmpeg -i "$INFILE" -acodec copy -vn "$OUTFILE"
else
    echo "no format recognized for file $INFILE"
    filename=$(basename -- "$INFILE")
    extension="${filename##*.}"
    OUTFILE="$NAME.$extension"
    cp "$INFILE" "$OUTFILE"
fi
kid3-cli -c "set artist \"$ARTIST feat. $LOID\""  "$FILE"
kid3-cli -c "set title \"$TITLE\""  "$FILE"
rm "$INFILE"
mv "$OUTFILE" "$TARGETDIR"
