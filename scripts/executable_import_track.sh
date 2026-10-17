#!/bin/bash
set -euo pipefail 
ARTIST=$(metaflac "$1" --show-tag=ARTIST | sed s/.*=//g)
TITLE=$(metaflac "$1" --show-tag=TITLE | sed s/.*=//g)

if [[ -n "$ARTIST" && -n "$TITLE" ]]; then
    # Calculate AcoustID fingerprint
    FINGERPRINT=$(fpcalc "$1" | grep -oP 'FINGERPRINT=\K.*')

    # Calculate SHA-256 hash of the fingerprint
    HASH=$(echo -n "$FINGERPRINT" | sha256sum | awk '{print $1}')

    # Save the fingerprint to the FLAC's tags
    metaflac --set-tag="ACOUSTID_FINGERPRINT=$FINGERPRINT" "$1"
    # python scripts/transcribe_tags.py "$1"

    #python ~/scripts/prompt_genre.py "$1"

    # Rename the file
    NEW_NAME="track-$HASH.flac"

    # Move to the destination directory
    mkdir -p "$2"
    echo "Imported $1 as $NEW_NAME"
    echo "$1;$NEW_NAME" >>musicimport.log
    mv -n "$1" "$2/$NEW_NAME"

    # Tag track ReplayGain the way Mixxx does (EBU R128 -> -18 LUFS)
    apply_replaygain.sh "$2/$NEW_NAME" || echo "Warning: ReplayGain tagging failed for $2/$NEW_NAME"
#    split_track.sh ~/audio/stems supermicro-old.ubinfra.lan:3939/split supermicro-old.ubinfra.lan:3942/mux/ "$2/$NEW_NAME"
else
    echo "Warning: File $1 does not have both ARTIST and TITLE tags set."
fi
