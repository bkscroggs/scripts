#!/bin/bash
# Version: 0.1.02

# --- Configuration & Colors ---
VERSION="0.1.02"
PROG_NAME="SyncTool"
CLR_PANEL='\033[0;36m' 
CLR_VAR='\033[0;35m'
CLR_YLW='\033[1;33m'
CLR_RED='\033[0;31m'
CLR_GRN='\033[0;32m'
CLR_RESET='\033[0m'
BOLD='\033[1m'

# --- Version Flag Handling ---
if [[ "$1" == "-v" || "$1" == "--version" ]]; then
    echo -e "${CLR_PANEL}${PROG_NAME}${CLR_RESET} version ${CLR_YLW}${VERSION}${CLR_RESET}"
    exit 0
fi

# --- Network & Paths ---
IP_TOWER="192.168.0.141"  
IP_LAPTOP="192.168.0.119" 
GDRIVE_BASE="/home/bryan/googledrive/Linux_stuff"
SCRIPT_DIR="/home/bryan/Programs/scripts"

# Identify current host to determine if "Remote" logic is needed
CURRENT_IP=$(hostname -I | awk '{print $1}')

# --- Functions ---

print_footer() {
    local col=$(tput cols); local row=$(tput lines)
    local footer="[ ${PROG_NAME} v${VERSION} ]"
    tput sc; tput cup "$((row - 1))" "$((col - ${#footer} - 1))"
    echo -ne "${CLR_PANEL}${footer}${CLR_RESET}"; tput rc 
}

print_header() {
    clear
    echo -e "${CLR_PANEL}==========================================${CLR_RESET}"
    echo -e "          ${BOLD}Kubuntu Sync Manager${CLR_RESET}          "
    echo -e "          Current Host: ${CLR_VAR}$(hostname)${CLR_RESET}"
    echo -e "${CLR_PANEL}==========================================${CLR_RESET}"
    print_footer
}

# --- Main Logic Loop ---

while true; do
    BASH_RESTRICT=0; IS_DIR=0; S_CLOUD_PATH=""; FORCE_SPECIFIC=0; CLOUD_TARGET_RESTRICT=0
    
    # 1. Source Selection
    print_header
    echo -e "${BOLD}Step 1: Select SOURCE System${CLR_RESET}"
    echo -e " 1) LinuxKubPC\n 2) Laptop\n 3) Google Drive"
    echo -e "\n 0) Exit Program"
    echo -ne "\nChoice: "
    read -r S_CHOICE
    [[ "$S_CHOICE" == "0" ]] && exit 0
    
    case $S_CHOICE in
        1) S_NAME="LinuxKubPC"; S_IP=$IP_TOWER; S_SPECIFIC="PC_Specific" ;;
        2) S_NAME="Laptop"; S_IP=$IP_LAPTOP; S_SPECIFIC="Laptop_Specific" ;;
        3) S_NAME="GoogleDrive"; S_IP="CLOUD"; S_SPECIFIC="" ;;
    esac

    if [[ "$S_NAME" == "GoogleDrive" ]]; then
        print_header
        echo -e "${BOLD}Select Google Drive Source Directory:${CLR_RESET}"
        echo -e " 1) Universal_Stuff\n 2) PC_Specific\n 3) Laptop_Specific\n 0) Back"
        read -r GD_SUB_CHOICE
        case $GD_SUB_CHOICE in
            1) S_CLOUD_PATH="Universal_Stuff"; CLOUD_TARGET_RESTRICT=0 ;;
            2) S_CLOUD_PATH="PC_Specific"; CLOUD_TARGET_RESTRICT=1 ;;
            3) S_CLOUD_PATH="Laptop_Specific"; CLOUD_TARGET_RESTRICT=2 ;;
            *) continue ;;
        esac
    fi

    # 2. Target Item Selection
    while true; do
        print_header
        echo -e "Source: ${CLR_VAR}$S_NAME${CLR_RESET} (${S_CLOUD_PATH:-"Local"})"
        echo -e "\n${BOLD}Step 2: Select Item to Sync${CLR_RESET}"
        printf "  %-22s %-20s\n" "1) .bashrc" "5) Terminator Config"
        printf "  %-22s %-20s\n" "2) .bash_aliases" "6) My Scripts"
        printf "  %-22s %-20s\n" "3) .vimrc" "7) .sncli"
        printf "  %-22s %-20s\n" "4) lsd configs" "8) .fzf.bash"
        echo -e "  ${CLR_YLW}T) [TEST] test_Script.sh${CLR_RESET}"
        echo -e "\n 0) Return to Source Selection"
        echo -ne "\nSelect: "
        read -r FILE_CHOICE
        [[ "$FILE_CHOICE" == "0" ]] && break

        case $FILE_CHOICE in
            1|2) [[ $FILE_CHOICE == 1 ]] && T_NAME=".bashrc" || T_NAME=".bash_aliases"; T_PATH="$T_NAME"; BASH_RESTRICT=1; FORCE_SPECIFIC=1 ;;
            3) T_NAME=".vimrc"; T_PATH=".vimrc"; BASH_RESTRICT=0; FORCE_SPECIFIC=0 ;;
            4) T_NAME="lsd"; T_PATH=".config/lsd/"; IS_DIR=1; FORCE_SPECIFIC=0 ;;
            5) T_NAME="Terminator"; T_PATH=".config/terminator/"; IS_DIR=1; FORCE_SPECIFIC=0 ;;
            6) 
                FORCE_SPECIFIC=1 
                print_header
                echo -e "${BOLD}Script Options (Source: $S_NAME)${CLR_RESET}"
                echo -e " 1) Sync Entire Directory (Recursive)\n 2) Select Specific Script\n 0) Back"
                read -r SCRIPT_OP
                if [[ "$SCRIPT_OP" == "1" ]]; then 
                    T_NAME="All Scripts"; T_PATH="Programs/scripts/"; IS_DIR=1
                elif [[ "$SCRIPT_OP" == "2" ]]; then
                    echo -e "\n${CLR_PANEL}[*] Fetching script list...${CLR_RESET}"
                    # --- REMOTE LISTING LOGIC ---
                    if [[ "$S_IP" == "CLOUD" ]]; then
                        # Google Drive Local Mount
                        mapfile -t SCRIPTS_ARRAY < <(ls -p "${GDRIVE_BASE}/${S_CLOUD_PATH}/Programs/scripts/" 2>/dev/null | grep -v /)
                    elif [[ "$S_IP" != "$CURRENT_IP" ]]; then
                        # SSH to other machine to list files
                        mapfile -t SCRIPTS_ARRAY < <(ssh "$S_IP" "ls -p $SCRIPT_DIR | grep -v /")
                    else
                        # Local Machine
                        mapfile -t SCRIPTS_ARRAY < <(ls -p "$SCRIPT_DIR" | grep -v /)
                    fi

                    if [[ ${#SCRIPTS_ARRAY[@]} -eq 0 ]]; then
                        echo -e "${CLR_RED}No scripts found or source unreachable.${CLR_RESET}"
                        sleep 2; continue
                    fi

                    for i in "${!SCRIPTS_ARRAY[@]}"; do printf " %2d) %s\n" "$((i+1))" "${SCRIPTS_ARRAY[$i]}"; done
                    read -r SCRIPT_INDEX; [[ "$SCRIPT_INDEX" == "0" ]] && continue
                    T_NAME="Script: ${SCRIPTS_ARRAY[$((SCRIPT_INDEX-1))]}"; T_PATH="Programs/scripts/${SCRIPTS_ARRAY[$((SCRIPT_INDEX-1))]}"
                else continue; fi ;;
            7|8) [[ $FILE_CHOICE == 7 ]] && T_NAME=".sncli" || T_NAME=".fzf.bash"; T_PATH="$T_NAME"; FORCE_SPECIFIC=0 ;;
            t|T) T_NAME="test_Script.sh"; T_PATH="Programs/scripts/test_Script.sh"; BASH_RESTRICT=0; IS_DIR=0; FORCE_SPECIFIC=0 ;;
            *) continue ;;
        esac

        # 3. Destination Selection
        while true; do
            print_header
            echo -e "Source: $S_NAME | Item: $T_NAME"
            echo -e "\n${BOLD}Step 3: Select DESTINATION System${CLR_RESET}"
            
            # Restriction Logic
            if [[ "$CLOUD_TARGET_RESTRICT" == "1" ]]; then echo " 1) LinuxKubPC"
            elif [[ "$CLOUD_TARGET_RESTRICT" == "2" ]]; then echo " 2) Laptop"
            elif [[ "$BASH_RESTRICT" == "1" && "$S_NAME" != "GoogleDrive" ]]; then echo " 3) Google Drive"
            elif [[ "$BASH_RESTRICT" == "1" && "$S_NAME" == "GoogleDrive" ]]; then echo " 1) LinuxKubPC"; echo " 2) Laptop"
            else [[ "$S_CHOICE" != "1" ]] && echo " 1) LinuxKubPC"; [[ "$S_CHOICE" != "2" ]] && echo " 2) Laptop"; [[ "$S_CHOICE" != "3" ]] && echo " 3) Google Drive"; fi
            echo -e "\n 0) Back"; read -r D_CHOICE
            [[ "$D_CHOICE" == "0" ]] && break
            
            case $D_CHOICE in
                1) D_NAME="LinuxKubPC"; D_IP=$IP_TOWER; D_SPECIFIC="PC_Specific" ;;
                2) D_NAME="Laptop"; D_IP=$IP_LAPTOP; D_SPECIFIC="Laptop_Specific" ;;
                3) D_NAME="GoogleDrive"; D_IP="CLOUD"; D_SPECIFIC="" ;;
            esac

            # Sub-Step: Google Drive Folder Selection
            D_FINAL_CLOUD_SUB=""
            if [[ "$D_NAME" == "GoogleDrive" ]]; then
                if [[ "$FORCE_SPECIFIC" == "1" ]]; then D_FINAL_CLOUD_SUB="$S_SPECIFIC"
                else
                    print_header
                    echo -e "${BOLD}Select Google Drive Destination:${CLR_RESET}\n 1) Universal_Stuff\n 2) ${S_SPECIFIC}\nChoice: "
                    read -r D_GD_CHOICE; [[ "$D_GD_CHOICE" == "1" ]] && D_FINAL_CLOUD_SUB="Universal_Stuff" || D_FINAL_CLOUD_SUB="$S_SPECIFIC"
                fi
                FINAL_DEST="${GDRIVE_BASE}/${D_FINAL_CLOUD_SUB}/${T_PATH}"
            else
                FINAL_DEST="${HOME}/${T_PATH}"
            fi

            # Source Path Construction
            [[ "$S_NAME" == "GoogleDrive" ]] && FINAL_SRC="${GDRIVE_BASE}/${S_CLOUD_PATH}/${T_PATH}" || FINAL_SRC="${HOME}/${T_PATH}"

            # 4. Final Summary
            print_header
            echo -e "  ${BOLD}SYNC PREVIEW${CLR_RESET}"
            echo -e "  ------------------------------------------"
            echo -e "  Source Host: $S_NAME"
            echo -e "  Path:        $FINAL_SRC"
            echo -e "  Dest Host:   $D_NAME"
            echo -e "  Path:        ${CLR_YLW}$FINAL_DEST${CLR_RESET}"
            
            # Network Ping
            if [[ "$D_IP" != "CLOUD" ]]; then
                echo -ne "  Network:     Checking $D_IP... "
                ping -c 1 -W 1 "$D_IP" > /dev/null 2>&1 && echo -e "[${CLR_GRN}ONLINE${CLR_RESET}]" || echo -e "[${CLR_RED}OFFLINE${CLR_RESET}]"
            else echo -e "  Network:     [${CLR_GRN}CLOUD MODE${CLR_RESET}]"; fi
            
            echo -e "  ------------------------------------------"
            echo -e "  1) Run Difference Check (Diff) & Simulate"
            echo -e "  2) Reset  3) Exit"
            read -r FINAL_CHOICE
            
            if [[ "$FINAL_CHOICE" == "1" ]]; then
                # Building the rsync command for summary
                RSYNC_CMD="rsync -vn"
                [[ "$IS_DIR" == "1" ]] && RSYNC_CMD="rsync -avn"
                
                # Handling Remote Syntax
                ACTUAL_SRC="$FINAL_SRC"; ACTUAL_DEST="$FINAL_DEST"
                [[ "$S_IP" != "CLOUD" && "$S_IP" != "$CURRENT_IP" ]] && ACTUAL_SRC="${S_IP}:${FINAL_SRC}"
                [[ "$D_IP" != "CLOUD" && "$D_IP" != "$CURRENT_IP" ]] && ACTUAL_DEST="${D_IP}:${FINAL_DEST}"

                print_header
                echo -e "${CLR_YLW}*** DIFFERENCE CHECK (Simulated) ***${CLR_RESET}"
                echo -e "Command: $RSYNC_CMD $ACTUAL_SRC $ACTUAL_DEST\n"
                echo -ne "\n${BOLD}Proceed with actual transfer? [y/N]:${CLR_RESET} "
                read -r CONFIRM_OVERWRITE
                if [[ "$CONFIRM_OVERWRITE" =~ ^[Yy]$ ]]; then
                    echo -e "\n${CLR_GRN}Simulation Complete. v0.1.02 Ready for Real rsync Activation.${CLR_RESET}"
                else echo -e "\n${CLR_RED}Transfer Aborted.${CLR_RESET}"; fi
                echo -e "\n1) New Transfer  2) Exit"; read -r NEXT; [[ "$NEXT" == "2" ]] && exit 0; continue 3
            elif [[ "$FINAL_CHOICE" == "2" ]]; then continue 3
            elif [[ "$FINAL_CHOICE" == "3" ]]; then exit 0; fi
        done
    done
done

# Version: 0.1.02
