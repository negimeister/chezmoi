#!/usr/bin/env bash
# Speed-read text RSVP-style (wrapper for clipread.py)
#
#   clipread.sh                 clipboard
#   clipread.sh -p              current selection
#   clipread.sh file.txt        a file
#   cmd | clipread.sh           piped text
#   clipread.sh -w 700 ...      any clipread.py option is passed through

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CLIPREAD="$SCRIPT_DIR/clipread.py"

# Last non-option argument that is a readable file -> read it via stdin
for arg in "$@"; do
    if [[ "$arg" != -* && -f "$arg" ]]; then
        file="$arg"
    fi
done

if [[ -n "$file" ]]; then
    args=()
    for arg in "$@"; do [[ "$arg" != "$file" ]] && args+=("$arg"); done
    exec python3 "$CLIPREAD" "${args[@]}" - < "$file"
elif [[ -p /dev/stdin || -f /dev/stdin ]]; then
    exec python3 "$CLIPREAD" "$@" -
else
    exec python3 "$CLIPREAD" "$@"
fi
