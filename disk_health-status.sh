# Script Version: 0.00.01
#!/bin/bash

# This is a simple bash script just to check to see if any installed drives' health
# are being monitored by the process 'smartctl' for an active self-test.

# Function to display version
show_version() {
    echo "Drive Health Test Checker Script - Version 0.00.01"
}

# Check for version flags
if [[ "$1" == "-v" || "$1" == "--version" ]]; then
    show_version
    exit 0
fi

echo "--- Initializing SMART Self-Test Status Check (v0.00.01) ---"

# Re-authenticate sudo privileges just once at the start.
echo "Authenticating sudo access..."
sudo -v
if [ $? -ne 0 ]; then
    echo "Error: Sudo authentication failed. Please run with appropriate permissions."
    exit 1
fi
echo "Authentication successful."
echo ""

# Loop through common drive paths and check for active self-tests
for drive in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
    # Check if the device file actually exists before running smartctl
    if [ -b "$drive" ]; then
        echo -n "Checking $drive: "
        # Run smartctl -a and grep for the specific line about self-test execution.
        # Redirect stderr to /dev/null to suppress "Device not ready" errors for non-existent devices in the loop expansion.
        output=$(sudo smartctl -a "$drive" 2>/dev/null | grep "Self-test execution")
        
        if [[ -n "$output" ]]; then
            echo "$output"
        else
            echo "No active test found or drive inaccessible."
        fi
    fi
done

echo ""
echo "--- Script Finished ---"

# Script Version: 0.00.01
