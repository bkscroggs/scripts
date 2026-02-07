#!/bin/bash
clear

# ANSI escape sequences for colors
GREEN=$(tput setaf 2)  # Green for success
RED=$(tput setaf 1)    # Red for timeout
RESET=$(tput sgr0)     # Reset color

# Addresses to ping
addresses=("192.168.0.192" "8.8.8.8" "192.168.0.1" "bkscroggs-himalayas.nord")

# Function to format and align the response column with fixed width
format_response() {
    local response=$1
    local max_length=50  # Fixed width for the response (e.g., "TIMEOUT" or "12.5 ms")

    # Pad the response to the right to ensure the column is always aligned
    printf "%-${max_length}s" "$response"
}

# Function to pad address to 15 characters for alignment
pad_address() {
    local address=$1
    local max_length=26
    printf "%-${max_length}s" "$address"
}

# Function to get formatted ping results
ping_address() {
    local address=$1
    local result=$(ping -c 1 -W 1 $address 2>/dev/null | grep 'time=' | awk -F'=' '{print $NF}' | cut -d' ' -f1)

    if [ -n "$result" ]; then
        # Format result with green color and right-alignment
        format_response "${GREEN}$result ms${RESET}"
    else
        # Format result with red color and right-alignment
        format_response "${RED}TIMEOUT${RESET}"
    fi
}

# Main loop
while true; do
    # Move the cursor up 4 lines to update the response column without moving the entire screen
    tput cuu 4

    # Print results in the same order every time
    i=0
    for addr in "${addresses[@]}"; do
        # Print each address followed by the ping result (without labels)
        echo -n "$(pad_address "${addresses[$i]}") | "
        ping_address "$addr"
        echo ""  # End the line after the response (no extra characters)
        ((i++))
    done

    # Sleep for 2 seconds before updating again
    sleep 2
done

