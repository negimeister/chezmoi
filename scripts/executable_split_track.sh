#!/bin/bash
set -e
VOCAL_MODEL=model_bs_roformer_ep_368_sdr_12.9628.ckpt
KARA_MODEL=mel_band_roformer_karaoke_becruily.ckpt

OUTPUT_DIR=$1
SPLITTER_URL=$2
MUXER_URL=$3
TRACK=$4

fullname=$(basename -- "$TRACK")
track_id="${fullname%.*}"

if [ -f $OUTPUT_DIR/$track_id.mp4 ]; then
    echo "Stems already exist at $OUTPUT_DIR/$track_id.mp4"
    exit 0
fi

tmp_dir=/tmp/$track_id/
vocal_dir=$tmp_dir/stems_vocal
kara_dir=$tmp_dir/stems_kara
merge_dir=$tmp_dir/stems_merged

mkdir -p $vocal_dir
mkdir -p $kara_dir
mkdir -p $merge_dir

echo "Splitting Vocals"
if [ ! -f $vocal_dir/stems.zip ]; then
    if curl -F "file=@$TRACK" -f $SPLITTER_URL/$VOCAL_MODEL --output $vocal_dir/stems.zip.part; then
        mv $vocal_dir/stems.zip.part $vocal_dir/stems.zip
    fi
fi
echo "Splitting Karaoke Vocals"
if [ ! -f $kara_dir/stems.zip ]; then
    if curl -F "file=@$TRACK" -f $SPLITTER_URL/$KARA_MODEL --output $kara_dir/stems.zip.part; then
        mv $kara_dir/stems.zip.part $kara_dir/stems.zip
    fi
fi
echo "Packing stems"
unzip -o -p $kara_dir/stems.zip "track (Vocals).flac" >"$merge_dir/track (Karaoke).flac"
unzip -o $vocal_dir/stems.zip -x "track (Nothing).flac" -d $merge_dir
zip -j -q -u $tmp_dir/merged.zip $merge_dir/*
echo "Muxing stem mp4"
if curl -f -F "file=@$tmp_dir/merged.zip" "$MUXER_URL" --output $tmp_dir/mux.mp4.part; then
    mv $tmp_dir/mux.mp4.part "$OUTPUT_DIR/$track_id.mp4"
fi
echo "Stem file generated $OUTPUT_DIR/$track_id.mp4"
