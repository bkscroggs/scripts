#!/bin/bash
# VERSION: 0.00.03

# --- Script to sync machine-specific dotfiles to a central GitHub Repo ---

VERSION="0.00.03"

# Handle version flags
if [[ "$1" == "-v" || "$1" == "--version" ]]; then
    echo "dot-git version $VERSION"
    exit 0
fi

# --- CONFIGURATION ---
REPO_URL="https://github.com/bkscroggs/my-dotfiles.git"
LOCAL_WORKSPACE="$HOME/Programs/dotfiles_git"
FILES_TO_SYNC=(".bashrc" ".bash_aliases")
MACHINE_NAME=$(hostname)

# 1. Setup or Update local workspace
if [ ! -d "$LOCAL_WORKSPACE/.git" ]; then
    echo "⚙️ Initializing local workspace in $LOCAL_WORKSPACE..."
    mkdir -p "$LOCAL_WORKSPACE"
    cd "$LOCAL_WORKSPACE" || exit
    git init
    git remote add origin "$REPO_URL"
    git fetch origin
    git checkout -b main || git checkout main
    git branch --set-upstream-to=origin/main main
else
    cd "$LOCAL_WORKSPACE" || exit
    echo "🔄 Syncing with GitHub to prevent conflicts..."
    git pull origin main --rebase
fi

# 2. Ensure the machine-specific folder exists
mkdir -p "$LOCAL_WORKSPACE/$MACHINE_NAME"

# 3. Sync files from Home to the Machine Folder
echo "📥 Grabbing latest files for $MACHINE_NAME..."
for file in "${FILES_TO_SYNC[@]}"; do
    if [ -f "$HOME/$file" ]; then
        cp "$HOME/$file" "$LOCAL_WORKSPACE/$MACHINE_NAME/"
    else
        echo "⚠️ Warning: $file not found in home directory."
    fi
done

# 4. Check for ANY changes (including untracked/new files)
# We add everything first so status can see it
git add .

if [[ -n $(git status --porcelain) ]]; then
    echo "✨ Changes detected for $MACHINE_NAME."
    
    echo "Enter a commit message:"
    read -r commit_msg
    
    git commit -m "[$MACHINE_NAME] Update: $commit_msg"
    
    if git push origin main; then
        echo "🚀 Successfully uploaded to my-dotfiles/$MACHINE_NAME!"
    else
        echo "❌ Error: Push failed. Check NordVPN or credentials."
    fi
else
    echo "✅ GitHub is already up to date for $MACHINE_NAME."
fi

# VERSION: 0.00.03

