#!/bin/bash
# Version: v0.0.1
# Description: Background daemon to auto-chmod +x new .sh and .py files

VERSION="v0.0.1"

if [[ "$1" == "-v" || "$1" == "--version" ]]; then
    echo "auto_chmod daemon version $VERSION"
    exit 0
fi

# The directory to watch (e.g., your scripts folder)
WATCH_DIR="$HOME/Programs/scripts"

# Check if directory exists
if [ ! -d "$WATCH_DIR" ]; then
    echo "Directory $WATCH_DIR does not exist. Please create it or edit this script."
    exit 1
fi

echo "Watching $WATCH_DIR for new scripts..."

# Monitor for 'create' and 'moved_to' events
inotifywait -m -r -e create -e moved_to --format '%w%f' "$WATCH_DIR" | while read NEWFILE
do
    # Check if the file is a .sh or .py file
    if [[ "$NEWFILE" == *.sh ]] || [[ "$NEWFILE" == *.py ]]; then
        chmod +x "$NEWFILE"
        echo "Automatically made $NEWFILE executable."
    fi
done

# Version: v0.0.1
