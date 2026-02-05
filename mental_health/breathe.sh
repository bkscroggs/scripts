#!/bin/bash
# Version 0.1.0

#this script is intended for relaxation purposes by defining how many cycles of deep breaths the user would like to perform. It is commandline based and instructs the user to take in a breath and for five seconds breath for five seconds, then hold their breath for five seconds, and then exhale their breath for an additional five seconds. This cycle repeats for the number of cycles that the user has inputted at the beginning of the script.

# Define color variables
LIGHT_BLUE='\033[1;34m'
LIGHT_YELLOW='\033[1;33m'
LIGHT_GREEN='\033[1;32m'
NC='\033[0m' # No Color

# Prompt the user for the number of cycles
read -p "Enter the number of breathing cycles: " cycles

# Function to display the breathing phase and countdown
display_phase() {
    phase=$1
    color=$2
    seconds=$3

    for ((i=seconds; i>=1; i--)); do
        clear
        echo -e "\n\tPhase: ${color}$phase${NC}"
        echo -e "\tTime: $i seconds"
        sleep 1
    done
}

# Main breathing cycle
for ((cycle=1; cycle<=cycles; cycle++)); do
    display_phase "Inhale" $LIGHT_BLUE 5
    display_phase "Hold" $LIGHT_YELLOW 5
    display_phase "Exhale" $LIGHT_GREEN 5

    # Pause before the next cycle
    clear
    echo -e "\nCycle $cycle completed. Prepare for the next cycle..."
    sleep 2
done

# Completion message
clear
echo -e "\nBreathing exercise completed. Well done!"

