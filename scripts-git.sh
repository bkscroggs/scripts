#!/bin/bash
# VERSION: 0.00.05

# --- Script to sync local scripts directly to GitHub (now forces rebase on pull) ---

VERSION="0.00.05"

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
    
    echo "Enter the version/message for this update (e.g., 0.00.05):"
    read -r commit_msg
    
    git commit -m "Update: $commit_msg"
    
    # --- NEW LOGIC START ---
    
    echo "Attempting to pull remote changes using rebase to prevent non-fast-forward rejection..."
    # We use --rebase to try and stack local commits cleanly on top of remote commits.
    if git pull --rebase origin main; then
        echo "Successfully pulled and rebased remote changes."
        
        echo "Now attempting to push local changes..."
        # Push and check for success
        if git push origin main; then
            echo "🚀 Successfully pushed to GitHub!"
        else
            echo "❌ Error: Push failed *after* a successful pull/rebase. Check NordVPN or your connection."
        fi
    else
        echo "❌ Error: Git pull --rebase failed."
        echo "This usually means there was a conflict during the rebase process."
        echo "You must manually resolve the conflicts in the terminal (look for <<<<<, =====, >>>>>) and then run 'git push origin main' (it might even need '--force-with-lease' if the rebase changed history, but let's stick to 'git push origin main' first)."
    fi
    # --- NEW LOGIC END ---
else
    echo "✅ Everything is already up to date."
fi

# VERSION: 0.00.05
