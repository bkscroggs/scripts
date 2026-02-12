#!/bin/bash
# VERSION: 0.00.04

# --- Script to sync local scripts directly to GitHub (now includes a pull) ---

VERSION="0.00.04"

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
    
    echo "Enter the version/message for this update (e.g., 0.00.04):"
    read -r commit_msg
    
    git commit -m "Update: $commit_msg"
    
    # --- NEW LOGIC START ---
    
    echo "Attempting to pull remote changes first to prevent non-fast-forward rejection..."
    if git pull origin main; then
        echo "Successfully pulled remote changes."
        
        echo "Now attempting to push local changes..."
        # Push and check for success
        if git push origin main; then
            echo "🚀 Successfully pushed to GitHub!"
        else
            echo "❌ Error: Push failed *after* a successful pull. Check NordVPN or your connection."
        fi
    else
        echo "❌ Error: Git pull failed (potential merge conflict or upstream issue)."
        echo "You must manually resolve any merge conflicts in the terminal and then run 'git push origin main'."
    fi
    # --- NEW LOGIC END ---
else
    echo "✅ Everything is already up to date."
fi

# VERSION: 0.00.04```

