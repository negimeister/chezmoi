#!/bin/bash
# apply_replaygain.sh [--force] [--dry-run] <file.flac>...
#
# Computes the track ReplayGain exactly the way Mixxx 2.5 does (EBU R128
# integrated loudness normalized to -18 LUFS, see mixxxrg) and stores it in
# the REPLAYGAIN_TRACK_GAIN tag. Files that already carry the tag are skipped
# unless --force is given.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
FORCE=0
DRY_RUN=0
FILES=()

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            echo "usage: apply_replaygain.sh [--force] [--dry-run] <file.flac>..."
            echo "  --force    retag files that already have REPLAYGAIN_TRACK_GAIN"
            echo "  --dry-run  print what would be tagged without writing"
            exit 0
            ;;
        *) FILES+=("$arg") ;;
    esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "usage: apply_replaygain.sh [--force] [--dry-run] <file.flac>..." >&2
    exit 2
fi

status=0
for f in "${FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "apply_replaygain: no such file: $f" >&2
        status=1
        continue
    fi
    existing=$(metaflac --show-tag=REPLAYGAIN_TRACK_GAIN "$f" 2>/dev/null | sed 's/.*=//')
    if [[ -n "$existing" && $FORCE -eq 0 ]]; then
        echo "skip (already tagged $existing): $f"
        continue
    fi
    value=$("$SCRIPT_DIR/mixxxrg" "$f")
    rc=$?
    if [[ $rc -eq 3 ]]; then
        echo "skip (unsupported sample rate, Mixxx skips RG too): $f"
        continue
    elif [[ $rc -ne 0 || -z "$value" ]]; then
        echo "apply_replaygain: mixxxrg failed (rc=$rc): $f" >&2
        status=1
        continue
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "would tag: $f -> $value"
    elif metaflac --set-tag="REPLAYGAIN_TRACK_GAIN=$value" "$f" 2>/dev/null; then
        echo "tagged: $f -> $value"
    else
        echo "apply_replaygain: failed to write tag: $f" >&2
        status=1
    fi
done
exit $status
