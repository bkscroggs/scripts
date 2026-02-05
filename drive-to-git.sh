#!/bin/bash
# VERSION: 0.00.03

# --- Script to sync local scripts directly to GitHub ---

VERSION="0.00.03"

# Handle version flags
if [[ "$1" == "-v" || "$1" == "--version" ]]; then
    echo "sync-scripts version $VERSION"
    exit 0
fi

# Navigate to the script directory
cd "$(dirname "$0")" || exit

# Check for changes
if [[ -n $(git status -s) ]]; then
    echo "Changes detected in ~/Programs/scripts/"
    git add .
    
    echo "Enter the version/message for this update (e.g., 0.00.01):"
    read -r commit_msg
    
    git commit -m "Update: $commit_msg"
    
    # Push and check for success
    if git push origin main; then
        echo "🚀 Successfully pushed to GitHub!"
    else
        echo "❌ Error: Push failed. Check NordVPN or your connection."
    fi
else
    echo "✅ Everything is already up to date."
fi

# VERSION: 0.00.03
