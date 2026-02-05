#!/bin/bash
# Version: 0.00.03

# --- 0. VERSION FLAG ---
for arg in "$@"; do
    if [[ "$arg" == "-v" ]] || [[ "$arg" == "--version" ]]; then
        echo "Snap-Nuke System Sanitizer - Version 0.00.03"
        exit 0
    fi
done

# --- 1. PRE-FLIGHT CHECKS ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo."
   exit 1
fi

echo "Starting Snap-Nuke 0.00.03: Purging Snap and installing native Firefox..."

# --- 2. REMOVE SNAP PACKAGES ---
echo "Removing snap packages..."
while [ "$(snap list 2>/dev/null | wc -l)" -gt 0 ]; do
    for s in $(snap list 2>/dev/null | tail -n +2 | awk '{print $1}'); do
        snap remove --purge "$s" 2>/dev/null
    done
done

# --- 3. PURGE DAEMON ---
echo "Purging snapd daemon..."
systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null
apt purge -y snapd

# --- 4. CLEAN DIRECTORIES ---
echo "Cleaning leftover directories..."
rm -rf ~/snap
rm -rf /snap
rm -rf /var/snap
rm -rf /var/lib/snapd
rm -rf /var/cache/snapd

# --- 5. THE BLOCKER (APT PINNING) ---
echo "Creating APT blocker to prevent Snap re-installation..."
cat <<EOF > /etc/apt/preferences.d/nosnap.pref
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

# --- 6. MOZILLA PPA SETUP ---
echo "Setting up Mozilla PPA for native Firefox..."
add-apt-repository -y ppa:mozillateam/ppa

cat <<EOF > /etc/apt/preferences.d/mozilla-ppa
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001

Package: thunderbird*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: -1
EOF

# --- 7. INSTALL NATIVE FIREFOX ---
echo "Updating cache and installing Firefox via PPA..."
apt update
apt install -y firefox

echo "------------------------------------------------------------"
echo "Done! Snap is gone, and Firefox is now a native .deb app."
echo "Your boot time should be even faster now!"
echo "------------------------------------------------------------"

# Version: 0.00.03
