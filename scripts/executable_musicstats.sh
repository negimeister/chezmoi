#!/bin/bash

# Check if the necessary tools are installed
if ! command -v metaflac &> /dev/null; then
    echo "metaflac command not found! Please install it."
    exit 1
fi

# Initialize counters
both_artist_and_title=0
album_set=0
cover_art_set=0
total_files=0

# Process each file
for file in "$@"; do
    if [ -f "$file" ]; then
        ((total_files++))

        # Check for artist and title tags
        artist=$(metaflac --show-tag=ARTIST "$file" | cut -d= -f2)
        title=$(metaflac --show-tag=TITLE "$file" | cut -d= -f2)
        if [ -n "$artist" ] && [ -n "$title" ]; then
            ((both_artist_and_title++))
        fi

        # Check for album tag
        album=$(metaflac --show-tag=ALBUM "$file" | cut -d= -f2)
        if [ -n "$album" ]; then
            ((album_set++))
        fi

        # Check for cover art
        has_picture=$(metaflac --list --block-type=PICTURE "$file")
        if [ -n "$has_picture" ]; then
            ((cover_art_set++))
        fi
    else
        echo "Warning: $file is not a regular file or does not exist."
    fi
done

# Calculate percentages
[ $total_files -eq 0 ] && total_files=1  # Avoid division by zero
both_artist_and_title_percentage=$(echo "scale=2; ($both_artist_and_title/$total_files)*100" | bc)
album_set_percentage=$(echo "scale=2; ($album_set/$total_files)*100" | bc)
cover_art_set_percentage=$(echo "scale=2; ($cover_art_set/$total_files)*100" | bc)

# Print results
echo "Total files processed: $total_files"
echo "Files with both artist and title set: $both_artist_and_title ($both_artist_and_title_percentage%)"
echo "Files with album set: $album_set ($album_set_percentage%)"
echo "Files with cover art set: $cover_art_set ($cover_art_set_percentage%)"

