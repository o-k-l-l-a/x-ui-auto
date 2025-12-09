#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}Run as root${plain}" && exit 1

DOMAIN="$1"
if [[ -z "$DOMAIN" ]]; then
    echo -e "${red}Usage:${plain}"
    echo "bash setup.sh yourdomain.com"
    exit 1
fi

# OS detect
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
else
    echo "Cannot detect OS"; exit 1
fi

install_base() {
    case "$release" in
        ubuntu|debian) apt update && apt install -y wget curl tar tzdata uuid-runtime ;;
        centos|rhel|almalinux|rocky) yum install -y wget curl tar tzdata uuid ;;
        *) apt update && apt install -y wget curl tar tzdata uuid-runtime ;;
    esac
}

install_xui() {
    cd /usr/local/
    tag=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" \
        | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    [[ -z "$tag" ]] && echo "Cannot fetch version" && exit 1

    wget -O x-ui.tar.gz \
        https://github.com/MHSanaei/3x-ui/releases/download/${tag}/x-ui-linux-amd64.tar.gz || exit 1

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
    mkdir -p /etc/x-ui/
    wget -O /etc/x-ui/x-ui.db \
        https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/x-ui.db || exit 1

    x-ui restart
}

############################################
### Generate UUIDs ###
############################################
UUID1=$(uuidgen)
UUID2=$(uuidgen)
UUID3=$(uuidgen)

mkdir -p /etc/x-ui/configs/

############################################
### 1) VLESS : 80
############################################
cat <<EOF >/etc/x-ui/configs/vless_80.json
{
  "v": "2",
  "ps": "VLESS-80",
  "add": "$DOMAIN",
  "port": 80,
  "id": "$UUID1",
  "scy": "none",
  "net": "ws",
  "tls": "none",
  "path": "/"
}
EOF

############################################
### 2) VMESS : 8080
############################################
cat <<EOF >/etc/x-ui/configs/vmess_8080.json
{
  "v": "2",
  "ps": "VMESS-8080",
  "add": "$DOMAIN",
  "port": 8080,
  "id": "$UUID2",
  "scy": "auto",
  "net": "ws",
  "tls": "none",
  "path": "/"
}
EOF

############################################
### 3) TROJAN : 8880
############################################
cat <<EOF >/etc/x-ui/configs/trojan_8880.json
{
  "protocol": "trojan",
  "password": "$UUID3",
  "address": "$DOMAIN",
  "port": 8880,
  "network": "ws",
  "path": "/",
  "security": "none"
}
EOF


##########################
### Output Section
##########################
echo -e "${green}"
echo "=========== LINKS FOR $DOMAIN =========="

echo ""
echo "🔹 VLESS 80:"
echo "vless://$UUID1@$DOMAIN:80?path=%2F&type=ws&security=none#VLESS-80"

echo ""
echo "🔹 VMESS 8080:"
VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "VMESS-8080",
  "add": "$DOMAIN",
  "port": "8080",
  "id": "$UUID2",
  "scy": "auto",
  "net": "ws",
  "tls": "none",
  "path": "/"
}
EOF
)
echo "vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"

echo ""
echo "🔹 TROJAN 8880:"
echo "trojan://$UUID3@$DOMAIN:8880?type=ws&path=%2F&security=none#TROJAN-8880"

echo ""
echo "========================================="
echo -e "${plain}"
