#!/bin/bash
# Version 0.1.0

#this script, searches a directory linked to the variable TARGET_DIR below and sorts through all videos and list them from oldest added to the most recent videos added. 
#if there is an error or no output, make sure that the target directory in this script is a valid Directory
#this script is originally intended for searching downloaded movies on an external hard drive

# Navigate to the specified path
TARGET_DIR="/media/bryan/Media/stuff to watch/"

# Check if the provided path exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: $TARGET_DIR is not a valid directory."
    exit 1
fi

# Add diagnostic output
echo "Searching for movie files in directory: $TARGET_DIR"

# List only movie files and format the output in green
find "$TARGET_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" \) -printf "%TY-%Tm-%Td %TH:%TM  %f\\n" | sort | while read -r line; do
    if [[ -n "$line" ]]; then
        # Output the line in green
        echo -e "\\033[0;32m$line\\033[0m"
    else
        echo "No movie files found."
    fi
done

