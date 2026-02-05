#!/bin/bash
# Version: 0.01.11

# Description: Monitors HDD/SSD health.
# Fixes "Monitoring exited too early" bug by improving regex matching.
# Waits for ALL tests to complete before generating the log.
# Combines SMART ID checks (197/198) with actual Self-Test results.

VERSION="0.01.11"

# --- 0. FLAG CHECK ---
for arg in "$@"; do
    if [[ "$arg" == "-v" ]] || [[ "$arg" == "--version" ]]; then
        echo "Disk Health Monitor Script - Version $VERSION"
        exit 0
    fi
done

# --- 1. SELF-ELEVATION ---
if [[ $EUID -ne 0 ]]; then
   echo "Elevating privileges..."
   sudo -E "$(readlink -f "$0")" "$@"
   exit $?
fi

# --- 2. STARTUP OPTIONS ---
echo -e "\033[1;36m=== Disk Health Monitor v$VERSION ===\033[0m"
read -p "Abort any existing/stuck tests before starting? (y/N): " abort_choice
if [[ "$abort_choice" =~ ^[Yy]$ ]]; then
    for drive in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
        [[ -e $drive ]] && smartctl -X $drive >/dev/null 2>&1
    done
    echo "Tests aborted. Waiting 5 seconds for drives to settle..."
    sleep 5
fi

# --- 3. AUTO-SCREEN (SSH PROTECTION) ---
if [[ (-n "$SSH_CONNECTION" || -n "$SSH_CLIENT") && -z "$STY" ]]; then
    echo -e "\033[1;35m[SSH DETECTED]\033[0m Starting screen session..."
    sleep 2
    exec screen -q -S DiskHealth "$(readlink -f "$0")" "$@"
fi

# --- 4. LOGGING SETUP ---
LOG_DIR="/home/$SUDO_USER/disk_health_log"
LOG_FILE="$LOG_DIR/disk_health_history.log"
mkdir -p "$LOG_DIR"
chown $SUDO_USER:$SUDO_USER "$LOG_DIR"

declare -A drive_modes
drives_to_monitor=""

# --- 5. PHASE 1: IDENTIFICATION & SELECTION ---
echo -e "\n\033[1;36m=== PHASE 1: Identification ===\033[0m"

for drive in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
    if [[ ! -e $drive ]]; then continue; fi
    
    # Get Info
    INFO_MODEL=$(smartctl -i $drive | grep -Ei "Device Model|Model Number" | cut -d: -f2- | xargs)
    INFO_SERIAL=$(smartctl -i $drive | grep -Ei "Serial Number" | cut -d: -f2- | xargs)
    INFO_SIZE=$(lsblk -dno SIZE $drive)
    
    echo -e "\n\033[1;33mDrive: $drive\033[0m ($INFO_SIZE)"
    echo -e "  ID: $INFO_MODEL | SN: $INFO_SERIAL"
    
    # Check if busy (Improved check)
    if smartctl -a $drive | grep -q "Self-test routine in progress"; then
        echo -e "  \033[1;35m[BUSY]\033[0m Test already running. Adding to monitor list."
        drive_modes["$drive"]="monitor"
        drives_to_monitor="$drives_to_monitor $drive"
        continue
    fi

    basename=$(basename $drive)
    is_hdd=$(cat /sys/block/$basename/queue/rotational 2>/dev/null)

    if [[ "$is_hdd" == "0" ]]; then
        echo "  Type: SSD/NVMe (Log Health Only)"
        drive_modes["$drive"]="ssd_log"
    else
        echo "  Type: Mechanical HDD"
        echo "  1) Short Test | 2) Long Test | 3) Skip"
        read -p "  Choice: " choice
        case $choice in
            1) smartctl -t short $drive > /dev/null; drive_modes["$drive"]="short_test"; drives_to_monitor="$drives_to_monitor $drive" ;;
            2) smartctl -t long $drive > /dev/null; drive_modes["$drive"]="long_test"; drives_to_monitor="$drives_to_monitor $drive" ;;
            *) drive_modes["$drive"]="skip" ;;
        esac
    fi
done

# --- 6. PHASE 2: GLOBAL MONITORING (Improved Logic) ---
echo -e "\n\033[1;36m=== PHASE 2: Global Monitoring ===\033[0m"
monitor_array=($drives_to_monitor)

if [[ ${#monitor_array[@]} -gt 0 ]]; then
    echo "Monitoring active tests... (This may take hours for Long Tests)"
    
    while true; do
        all_finished=true
        output_line=""

        for drive in "${monitor_array[@]}"; do
            # Capture full smartctl output to variable to avoid running it twice
            smart_output=$(smartctl -a $drive 2>/dev/null)
            
            # Check strictly if "routine in progress" string exists
            if echo "$smart_output" | grep -q "Self-test routine in progress"; then
                all_finished=false
                # Try to extract percentage, default to "Running" if regex fails
                pct=$(echo "$smart_output" | grep -oE "[0-9]+% of test remaining|[0-9]+% remaining" | head -1)
                [[ -z "$pct" ]] && pct="Running..."
                output_line="$output_line [${drive##*/}: $pct]"
            else
                output_line="$output_line [${drive##*/}: Done]"
            fi
        done

        # Print status line
        echo -ne "\r\033[K$output_line"
        
        if $all_finished; then
            echo -e "\n\nAll tests completed. Proceeding to analysis."
            break
        fi
        
        sleep 30
    done
fi

# --- 7. PHASE 3: ANALYSIS & LOGGING ---
echo -e "\n\033[1;36m=== PHASE 3: Generating Log ===\033[0m"
FAIL_SUMMARY=""

{
    echo -e "\n\n======================================================================"
    echo " SESSION REPORT: $(date '+%Y-%m-%d %H:%M:%S') (v$VERSION)"
    echo "======================================================================"
} >> "$LOG_FILE"

for drive in "${!drive_modes[@]}"; do
    mode=${drive_modes["$drive"]}
    pwr_hours=$(smartctl -A $drive 2>/dev/null | grep -Ei "Power_On_Hours|Power-on Hours" | awk '{print $NF}')
    sn=$(smartctl -i $drive | grep -Ei "Serial Number" | cut -d: -f2- | xargs)

    if [[ "$mode" == "ssd_log" ]]; then
        status=$(smartctl -H $drive | grep 'overall' | awk '{print $6}')
        { 
            echo "Drive: $drive | SN: $sn (SSD)"
            echo "Status: $status"
            echo "Hours: $pwr_hours"
            echo "-------------------------------------------" 
        } >> "$LOG_FILE"
    
    elif [[ "$mode" != "skip" ]]; then
        # 1. Check Bad Sectors (Physical Damage)
        fail_check=$(smartctl -A $drive | awk '$1 == 197 || $1 == 198 {sum += $10} END {print sum}')
        
        # 2. Check Result of the Test We Just Ran (Log entry #1)
        test_result=$(smartctl -l selftest $drive | grep "# 1" | head -1)
        test_status=$(echo "$test_result" | awk '{print $3, $4, $5}')
        
        status_flag="PASSED"
        
        # Logic: If bad sectors exist OR if the test log says anything other than "Completed without error"
        if [[ "$fail_check" -gt 0 ]]; then
            status_flag="FAILED (Physical Bad Sectors Found: $fail_check)"
            FAIL_SUMMARY="$FAIL_SUMMARY\n[!] $drive: Bad Sectors Found"
        elif [[ "$test_status" != *"without error"* ]]; then
            status_flag="FAILED (Self-Test Failed: $test_status)"
            FAIL_SUMMARY="$FAIL_SUMMARY\n[!] $drive: Self-Test Failed"
        fi

        {
            echo "Drive: $drive | SN: $sn"
            echo "Assessment: $status_flag"
            echo "Bad Sectors (197/198): ${fail_check:-0}"
            echo "Last Test Result: $test_result"
            echo "Hours: $pwr_hours"
            echo "-------------------------------------------"
        } >> "$LOG_FILE"
    fi
done

echo "Log updated: $LOG_FILE"
chown $SUDO_USER:$SUDO_USER "$LOG_FILE"

# --- 8. NOTIFICATION ---
NOTIFY_MSG="DISK HEALTH SCAN COMPLETE.\nLog: $LOG_FILE"
if [[ -n "$FAIL_SUMMARY" ]]; then
    NOTIFY_MSG="WARNING: FAILURES DETECTED! $FAIL_SUMMARY\n\n$NOTIFY_MSG"
fi

echo -e "$NOTIFY_MSG" | wall
sudo -u $SUDO_USER DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $SUDO_USER)/bus notify-send "Disk Health" "Scan Complete" --icon=drive-harddisk 2>/dev/null

echo -e "\n\033[1;32mScript finished successfully.\033[0m"

# Version: 0.01.11
