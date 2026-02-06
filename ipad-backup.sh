#!/bin/bash
# VERSION: v0.00.07
# AUTHOR: AI Assistant
# DESCRIPTION: iPad backup with dual-mode progress (Percentage + File Count).

VERSION="v0.00.07"
BACKUP_DIR="$HOME/IPad_backup"
DATE_STAMP=$(date +%Y-%m-%d)
TARGET_PATH="$BACKUP_DIR/ipad-$DATE_STAMP"
DRY_RUN=false
VERBOSE=false

show_help() {
    echo "Usage: ipad-backup [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --dry-run     Creates directory and a test file, but skips the backup."
    echo "  -V, --verbose     Show EVERY line from idevicebackup2 (firehose mode)."
    echo "  -h, --help        Show this help message."
    echo "  -v, --version     Show version information."
}

show_version() {
    echo "ipad-backup version $VERSION"
}

draw_progress_bar() {
    local progress=$1
    local file_info=$2
    if [[ ! "$progress" =~ ^[0-9]+$ ]]; then return; fi
    
    local filled=$((progress / 2))
    local empty=$((50 - filled))
    
    # Clear line and print info
    printf "\r\033[K" # Clear current line
    if [ -n "$file_info" ]; then
        echo -ne "📄 Last file: ${file_info: -50}\n" # Show last 50 chars of file
        printf "\033[1A" # Move cursor back up one line
    fi
    
    printf "Progress: ["
    printf "%${filled}s" | tr ' ' '■'
    printf "%${empty}s" | tr ' ' ' '
    printf "] %d%%" "$progress"
}

check_pairing() {
    echo "🔍 Checking USB connection..."
    DEVICE_ID=$(idevice_id -l | head -n 1)
    if [ -z "$DEVICE_ID" ]; then
        echo "❌ Error: No iPad detected. Try re-plugging the cable."
        exit 1
    fi
    PAIR_CHECK=$(idevicepair validate 2>&1)
    if [[ "${PAIR_CHECK^^}" == *"SUCCESS"* ]]; then
        echo "✅ Device is paired and trusted."
    else
        echo "⚠️  Pairing check failed. Attempting to trigger trust prompt..."
        idevicepair pair
        sleep 2
    fi
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--version) show_version; exit 0 ;;
        -h|--help) show_help; exit 0 ;;
        -d|--dry-run) DRY_RUN=true; shift ;;
        -V|--verbose) VERBOSE=true; shift ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
done

echo "---------------------------------------------------"
echo "📱 iPad Backup Utility ($VERSION) on LinuxKubPC"
echo "---------------------------------------------------"

mkdir -p "$TARGET_PATH"

if [ "$DRY_RUN" = true ]; then
    echo "🧪 Mode: DRY RUN - Writing verification to $TARGET_PATH"
    echo "Dry run: $(date)" > "$TARGET_PATH/dry_run_success.txt"
    exit 0
fi

check_pairing
echo "🚀 Backing up to Samsung 990 Pro..."
echo "---------------------------------------------------"

file_count=0
current_percent=0

# Use stdbuf and a more inclusive regex
stdbuf -oL idevicebackup2 backup "$TARGET_PATH" 2>&1 | while IFS= read -r line; do
    if [[ "$VERBOSE" = true ]]; then
        echo "$line"
        continue
    fi

    # Check for Percentage
    if [[ "$line" =~ ([0-9]+)(\.[0-9]+)?% ]]; then
        current_percent="${BASH_REMATCH[1]}"
        draw_progress_bar "$current_percent" ""
    # Check if it looks like a file path (contains a slash and common extensions)
    elif [[ "$line" == *"/"* ]] || [[ "$line" == *"Sending"* ]]; then
        ((file_count++))
        # If no percentage is moving, show file count
        if [ "$current_percent" -eq 0 ]; then
            printf "\rProcessed %d files... " "$file_count"
        else
            # Extract just the filename for the "Last file" display
            fname=$(basename "$line")
            draw_progress_bar "$current_percent" "$fname"
        fi
    fi
done

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "\n---------------------------------------------------"
    echo "✅ Success! Backup completed to $TARGET_PATH"
else
    echo -e "\n---------------------------------------------------"
    echo "❌ Error: Backup failed. If it stopped early, check iPad storage/cable."
    exit 1
fi

# VERSION: v0.00.07
