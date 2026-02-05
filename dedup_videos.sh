#!/bin/bash
# Version: 0.00.02

# --- Script Logic ---
VERSION="0.00.02"
FILE="dups.txt"

# Handle version flags
if [[ "$1" == "-v" || "$1" == "--version" ]]; then
    echo "dedup_videos.sh version $VERSION"
    exit 0
fi

if [[ ! -f "$FILE" ]]; then
    echo "Error: $FILE not found."
    exit 1
fi

echo "Starting deletion process..."
echo "------------------------------------------------"

new_group=true

while IFS= read -r line || [[ -n "$line" ]]; do
    # Check if line is empty (group separator)
    if [[ -z "$line" ]]; then
        new_group=true
        continue
    fi

    # If it's the first line of a new group, delete it
    if [ "$new_group" = true ]; then
        if [ -f "$line" ]; then
            rm "$line"
            echo "[DELETED] $line"
        elif [ -d "$line" ]; then
            echo "[SKIP] $line is a directory, not deleting."
        else
            echo "[NOT FOUND] Skipping: $line"
        fi
        new_group=false
    else
        # We skip the rest of the files in the group (the "keepers")
        continue
    fi
done < "$FILE"

echo "------------------------------------------------"
echo "Process complete. Duplicates removed."

# Version: 0.00.02

