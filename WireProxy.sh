#!/bin/bash
set -e

# ===============================
# WireProxy Auto-install on Ubuntu (non-interactive, port 4848)
# ===============================

WP_INSTALL_PORT="4848"

# -------------------------------
# Check root
# -------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Please run this script as root!"
    exit 1
fi

# -------------------------------
# Install dependencies
# -------------------------------
echo "[INFO] Installing required packages..."
apt -y update
apt -y install wget net-tools curl

# -------------------------------
# Setup warp command
# -------------------------------
echo "[INFO] Setting up warp command..."
mkdir -p /etc/wireguard
wget -q -N -P /etc/wireguard https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh
chmod +x /etc/wireguard/menu.sh
ln -sf /etc/wireguard/menu.sh /usr/bin/warp

# -------------------------------
# Install WireProxy (Warp Socks5 Proxy)
# -------------------------------
echo "[INFO] Installing WireProxy on port ${WP_INSTALL_PORT}..."
warp w <<< $'1\n1\n'"${WP_INSTALL_PORT}"$'\n1\n'

# -------------------------------
# Start WireProxy
# -------------------------------
echo "[INFO] Starting WireProxy service..."
systemctl start wireproxy
sleep 2

# -------------------------------
# Check status
# -------------------------------
if ss -nltp | grep -q wireproxy; then
    echo "[SUCCESS] WireProxy is running on socks5://127.0.0.1:${WP_INSTALL_PORT}"
else
    echo "[ERROR] WireProxy failed to start."
fi
