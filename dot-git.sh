#!/bin/bash
# VERSION: 0.01.08

# --- Script to sync machine-specific dotfiles to a central GitHub Repo ---

VERSION="0.01.08"

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
    echo "🔄 Local workspace ready. Proceeding to sync local files to repository."
fi

# 2. Ensure the machine-specific folder and the new config folder exist
MACHINE_DIR="$LOCAL_WORKSPACE/$MACHINE_NAME"
CONFIG_DIR="$MACHINE_DIR/$CONFIG_SUBDIR"
mkdir -p "$MACHINE_DIR"
mkdir -p "$CONFIG_DIR"

# --- DIAGNOSTIC STEP: Make a guaranteed change on the Desktop ---
# This ensures we have something new to push if the script is running correctly.
if [[ "$MACHINE_NAME" == "LinuxKubPC" ]]; then 
    echo "--- DIAGNOSTIC: Adding unique marker to Desktop's .bashrc ---"
    echo "# Desktop Marker $(date +%s)" >> "$HOME/.bashrc"
fi
# -----------------------------------------------------------------


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

# 4. Check for ANY changes (including untracked/new files)
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

# VERSION: 0.01.08
