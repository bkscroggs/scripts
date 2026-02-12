#!/bin/bash
# VERSION: 0.01.10

# --- Script to sync machine-specific dotfiles to a central GitHub Repo ---

VERSION="0.01.10"

# Handle version flags
if [[ "$1" == "-v" || "$1" == "--version" ]]; then
    echo "dot-git version $VERSION"
    exit 0
fi

# --- CONFIGURATION ---
REPO_URL="https://github.com/bkscroggs/my-dotfiles.git"
LOCAL_WORKSPACE="$HOME/Programs/dotfiles_git"
MACHINE_NAME=$(hostname)

# --- FILE/DIRECTORY DEFINITIONS ---
# 1. Files to sync directly under $MACHINE_NAME/ (Root Level)
FILES_TO_SYNC_ROOT=(".bashrc" ".bash_aliases") 

# 2. Items to sync into the $MACHINE_NAME/$CONFIG_SUBDIR/ folder
# Note: Directories are copied recursively (cp -r)
FILES_TO_SYNC_CONFIG=(
    ".gitconfig"
    ".hushlogin"
    ".snclirc"
    ".vimrc"
    ".config/terminator"  # Source path from $HOME
    ".config/lsd"         # Source path from $HOME
    ".vim"                # Directory
)
CONFIG_SUBDIR="config_files" 

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
    # Pull with rebase to integrate remote changes BEFORE local sync
    if git pull --rebase origin main; then
        echo "✅ Git pull/rebase successful."
    else
        echo "❌ ERROR: Git pull/rebase failed. You may have local merge conflicts to resolve manually."
        exit 1 # Exit if pull fails, as we can't safely proceed with local sync
    fi
fi

# 2. Ensure the machine-specific folder and the new config folder exist
MACHINE_DIR="$LOCAL_WORKSPACE/$MACHINE_NAME"
CONFIG_DIR="$MACHINE_DIR/$CONFIG_SUBDIR"
mkdir -p "$MACHINE_DIR"
mkdir -p "$CONFIG_DIR"

# 3a. SYNC: Copy Root Level Files FROM $HOME/ TO Git Workspace (For Uploading Changes)
echo "📥 SYNC: Grabbing latest files for $MACHINE_NAME (Root Level) TO Git workspace..."
for file in "${FILES_TO_SYNC_ROOT[@]}"; do
    if [ -f "$HOME/$file" ]; then
        echo "   -> Copying $file from $HOME/ to Git workspace."
        cp "$HOME/$file" "$MACHINE_DIR/"
    else
        echo "⚠️ Warning: Root file $file not found in home directory. Skipping copy."
    fi
done

# 3b. SYNC: Copy Config Files/Directories into the $CONFIG_SUBDIR (For Uploading Changes)
echo "📥 SYNC: Grabbing configuration items into $CONFIG_SUBDIR..."
for item in "${FILES_TO_SYNC_CONFIG[@]}"; do
    SOURCE_PATH="$HOME/$item"
    DEST_PATH="$CONFIG_DIR/"
    
    if [ -e "$SOURCE_PATH" ]; then
        if [ -d "$SOURCE_PATH" ]; then
            # Handle directories recursively
            echo "   -> Copying directory: $item"
            cp -rf "$SOURCE_PATH" "$DEST_PATH"
        elif [ -f "$SOURCE_PATH" ]; then
            # Handle single files
            echo "   -> Copying file: $item"
            cp -f "$SOURCE_PATH" "$DEST_PATH"
        fi
    else
        echo "⚠️ Warning: Config item $item not found in home directory."
    fi
done

# 4a. Check for ANY changes
git add .
STATUS_OUTPUT=$(git status --porcelain)

if [[ -n $STATUS_OUTPUT ]]; then
    echo "✨ Changes detected for $MACHINE_NAME."
    
    # 4b. NEW: Parse and display status changes
    echo "--- Git Status Summary ---"
    echo "$STATUS_OUTPUT" | while read -r line; do
        STATUS_CODE=${line:0:2}
        FILE_PATH=${line:3}
        
        ACTION="Unknown"
        if [[ "$STATUS_CODE" == "A " ]]; then ACTION="ADDED"; fi
        if [[ "$STATUS_CODE" == "M " ]]; then ACTION="MODIFIED"; fi
        if [[ "$STATUS_CODE" == "D " ]]; then ACTION="DELETED"; fi
        if [[ "$STATUS_CODE" == "MM" ]]; then ACTION="MODIFIED (Both)"; fi
        
        echo "  [$ACTION] $FILE_PATH"
    done
    echo "--------------------------"
    
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

# VERSION: 0.01.10
