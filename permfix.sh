#!/bin/bash
# Version: v0.0.1
# Description: Recursively adds executable permissions to files in a directory.

VERSION="v0.0.1"

# Function to show version
show_version() {
    echo "permfix utility version $VERSION"
}

# Check for version flags
if [[ "$1" == "-v" || "$1" == "--version" ]]; then
    show_version
    exit 0
fi

# Target directory (default to current directory if not provided)
TARGET_DIR="${1:-.}"

echo "Making all files in $TARGET_DIR executable..."

# The 'find' command ensures we don't mess up directory permissions
find "$TARGET_DIR" -type f -exec chmod +x {} +

echo "Done! Your scripts are ready to run on LinuxKubPC or your laptop."

# Version: v0.0.1
