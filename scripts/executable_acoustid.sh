#!/bin/bash

API_KEY="b'epHssqUw"

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 file1.flac [file2.flac ...]"
    exit 1
fi

# Loop through all provided files
for file in "$@"; do
    # Check if the file is a valid FLAC before processing
    if file "$file" | grep -q FLAC; then
        # Extract metadata from FLAC file
        ACOUSTID_FINGERPRINT=$(metaflac --show-tag=ACOUSTID_FINGERPRINT "$file" | cut -d= -f2)
        TOTAL_SAMPLES=$(metaflac --show-total-samples "$file")
        SAMPLE_RATE=$(metaflac --show-sample-rate "$file")
        DURATION=$(awk "BEGIN {printf \"%.0f\", $TOTAL_SAMPLES/$SAMPLE_RATE}")
        
        # If the fingerprint and duration are available, make a request
        if [[ -n "$ACOUSTID_FINGERPRINT" && -n "$DURATION" ]]; then
            response=$(curl -s "https://api.acoustid.org/v2/lookup?fingerprint=$ACOUSTID_FINGERPRINT&duration=$DURATION&client=$API_KEY")
            
            # Extract some info from the response
            status=$(echo "$response" | jq -r .status)
            results_count=$(echo "$response" | jq '.results | length')
                
            if [[ "$status" == "ok" ]]; then
                if [ "$results_count" -eq 1 ]; then
                    acoustid_id=$(echo "$response" | jq -r '.results[0].id')
                    echo "Writing AcoustID: $acoustid_id to $file"
                    metaflac --set-tag="ACOUSTID_ID=$acoustid_id" "$file"
                    metaflac --set-tag="GROUPING=$acoustid_id" "$file"
                elif [ "$results_count" -eq 0 ]; then
                    echo "No AcoustID found for $file"
                else
                    echo "Multiple AcoustIDs found for $file. Skipping."
                fi
            else
                echo "Error for file $file: $response"
            fi
            
            # Ensure not more than 3 requests are made per second
            sleep 0.34
        fi
    else
        echo "Error: $file is not a valid FLAC file."
    fi
done
