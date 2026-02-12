#!/bin/bash
# VERSION: 0.00.06

# --- Script to sync local scripts directly to GitHub (now shows detailed file status) ---

VERSION="0.00.06"

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
    
    # 1. Show files staged *before* committing
    echo "--- Files Staged for Commit (git status -s) ---"
    git status -s
    echo "----------------------------------------------"
    
    git add .
    
    echo "Enter the version/message for this update (e.g., 0.00.06):"
    read -r commit_msg
    
    # 2. Commit (output will show file changes)
    git commit -m "Update: $commit_msg"
    
    # --- NEW LOGIC START ---
    
    echo "Attempting to pull remote changes using rebase to prevent non-fast-forward rejection..."
    # We use --rebase to try and stack local commits cleanly on top of remote commits.
    if git pull --rebase origin main; then
        echo "Successfully pulled and rebased remote changes."
        
        # 3. Show final status *after* pull/rebase but *before* push
        echo "--- Final Status Before Push (git status -s) ---"
        git status -s
        echo "------------------------------------------------"
        
        echo "Now attempting to push local changes..."
        # Push and check for success
        if git push origin main; then
            echo "🚀 Successfully pushed to GitHub!"
        else
            echo "❌ Error: Push failed *after* a successful pull/rebase. Check NordVPN or your connection."
        fi
    else
        echo "❌ Error: Git pull --rebase failed."
        echo "This confirms there was a conflict during the rebase process."
        echo "You must manually resolve the conflicts in the terminal (look for <<<<<, =====, >>>>>) and then run 'git push origin main' to finish."
    fi
    # --- NEW LOGIC END ---
else
    echo "✅ Everything is already up to date."
fi

# VERSION: 0.00.06
