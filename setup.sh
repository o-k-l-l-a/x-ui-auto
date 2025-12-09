#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

# Root check
[[ $EUID -ne 0 ]] && echo -e "${red}Please run as root${plain}" && exit 1

# Domain from arg
DOMAIN="$1"
if [[ -z "$DOMAIN" ]]; then
    echo -e "${red}You must enter domain like:${plain}"
    echo "bash setup.sh example.com"
    exit 1
fi

# Detect OS
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
else
    echo "Cannot detect OS!"
    exit 1
fi

# Install base
install_base() {
    case "${release}" in
        ubuntu|debian)
            apt update && apt install -y wget curl tar tzdata ;;
        centos|rhel|almalinux|rocky)
            yum install -y wget curl tar tzdata ;;
        *)
            apt update && apt install -y wget curl tar tzdata ;;
    esac
}

install_xui() {
    cd /usr/local/

    tag=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" \
        | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    [[ -z "$tag" ]] && echo "Cannot fetch version!" && exit 1

    echo -e "${green}Installing x-ui $tag ...${plain}"

    wget -O x-ui.tar.gz \
        https://github.com/MHSanaei/3x-ui/releases/download/${tag}/x-ui-linux-amd64.tar.gz \
        || exit 1

    systemctl stop x-ui 2>/dev/null
    rm -rf /usr/local/x-ui

    tar -xzf x-ui.tar.gz
    rm -f x-ui.tar.gz

    cd x-ui
    chmod +x x-ui x-ui.sh bin/*

    cp -f x-ui.service /etc/systemd/system/
    mv -f x-ui.sh /usr/bin/x-ui
    chmod +x /usr/bin/x-ui

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
}

replace_database() {
    echo -e "${green}Downloading new x-ui.db ...${plain}"

    mkdir -p /etc/x-ui/
    wget -O /etc/x-ui/x-ui.db \
        https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/x-ui.db \
        || (echo "Download failed!" && exit 1)

    echo -e "${green}Restarting x-ui ...${plain}"
    x-ui restart
}

# RUN
install_base
install_xui
replace_database


#############################################
### NEW SECTION — SAVE 3 JSON CONFIG FILES ###
#############################################

mkdir -p /etc/x-ui/configs/

# 1) VLESS
cat <<EOF >/etc/x-ui/configs/vless_80.json
{
  "v": "2",
  "ps": "VLESS-80",
  "add": "$DOMAIN",
  "port": 80,
  "id": "80",
  "scy": "none",
  "net": "ws",
  "tls": "none",
  "path": "/",
  "type": "none"
}
EOF

# 2) VMESS
cat <<EOF >/etc/x-ui/configs/vmess_8080.json
{
  "v": "2",
  "ps": "VMESS-8080",
  "add": "$DOMAIN",
  "port": 8080,
  "id": "8080",
  "scy": "auto",
  "net": "ws",
  "tls": "none",
  "path": "/",
  "type": "none"
}
EOF

# 3) TROJAN
cat <<EOF >/etc/x-ui/configs/trojan_8880.json
{
  "protocol": "trojan",
  "password": "8880",
  "address": "$DOMAIN",
  "port": 8880,
  "network": "ws",
  "path": "/",
  "security": "none"
}
EOF

echo -e "${green}Saved configs in: /etc/x-ui/configs/${plain}"


###################################
###  OUTPUT SECTION (LINKS)     ###
###################################

echo -e "${green}"
echo "===== PROXY LINKS FOR DOMAIN: $DOMAIN ====="
echo ""

### 1) VLESS
echo "vless://80@$DOMAIN:80?type=ws&encryption=none&path=%2F&host=&security=none#80-80"
echo ""

### 2) VMESS
VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "8080-8080",
  "add": "$DOMAIN",
  "port": 8080,
  "id": "8080",
  "scy": "auto",
  "net": "ws",
  "tls": "none",
  "path": "/",
  "host": "",
  "type": "none"
}
EOF
)

VMESS_B64=$(echo -n "$VMESS_JSON" | base64 -w 0)
echo "vmess://$VMESS_B64"
echo ""

### 3) TROJAN
echo "trojan://8880@$DOMAIN:8880?type=ws&path=%2F&host=&security=none#8880-8880"
echo ""

echo "============================================"
echo -e "${plain}"
