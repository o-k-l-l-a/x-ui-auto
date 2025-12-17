#!/bin/bash

########################
# Root check
########################
[[ $EUID -ne 0 ]] && echo "Run as root" && exit 1

########################
# Colors
########################
red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

########################
# Check domains
########################
if [[ $# -lt 1 ]]; then
    echo -e "${red}Usage:${plain}"
    echo "bash setup.sh domain1.com domain2.com domain3.com"
    exit 1
fi

DOMAINS=("$@")

########################
# Cleanup old stuff
########################
echo "y" | x-ui uninstall
echo "y" | warp u

########################
# Firewall
########################
apt update -y
apt install -y ufw

ufw allow 22
ufw allow 80
ufw allow 8080
ufw allow 2095
ufw allow 4848

echo "y" | ufw disable
echo "y" | ufw enable
ufw reload

########################
# WARP
########################
bash <(curl -s https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/WireProxy.sh)

########################
# Detect OS
########################
source /etc/os-release
release=$ID

install_base() {
    case "$release" in
        ubuntu|debian) apt install -y wget curl tar tzdata ;;
        centos|rhel|almalinux|rocky) yum install -y wget curl tar tzdata ;;
        *) apt install -y wget curl tar tzdata ;;
    esac
}

########################
# Install X-UI
########################
install_xui() {
    echo -e "${green}Installing X-UI ...${plain}"
    cd /usr/local || exit 1

    tag=$(curl -Ls https://api.github.com/repos/MHSanaei/3x-ui/releases/latest \
        | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64|arm64) FILE="x-ui-linux-arm64.tar.gz" ;;
        x86_64) FILE="x-ui-linux-amd64.tar.gz" ;;
        *) FILE="x-ui-linux-amd64.tar.gz" ;;
    esac

    wget -O x-ui.tar.gz \
      https://github.com/MHSanaei/3x-ui/releases/download/${tag}/${FILE} || exit 1

    systemctl stop x-ui 2>/dev/null
    rm -rf /usr/local/x-ui

    tar -xzf x-ui.tar.gz
    rm -f x-ui.tar.gz

    cd x-ui || exit 1
    chmod +x x-ui x-ui.sh bin/*

    cp x-ui.service /etc/systemd/system/
    mv x-ui.sh /usr/bin/x-ui

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
}

########################
# Replace DB
########################
replace_database() {
    local DB_DIR="/etc/x-ui"
    local DB_FILE="x-ui.db"
    local DB_URL="https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/x-ui.db"

    mkdir -p "$DB_DIR" || exit 1
    wget -q -O "$DB_DIR/$DB_FILE" "$DB_URL" || exit 1

    x-ui restart
}

install_base
install_xui
replace_database

########################
# Create VLESS txt files (fixed names)
########################
i=1
for DOMAIN in "${DOMAINS[@]}"; do

cat <<EOF >/root/domin${i}.txt
vless://80@${DOMAIN}:80?type=ws&encryption=none&path=%2F&security=none#80-${DOMAIN}
EOF

((i++))
done

########################
# Output
########################
echo -e "${green}"
echo "=========== DONE =========="
echo "Created files:"
ls /root/domin*.txt
echo "==========================="
echo -e "${plain}"
