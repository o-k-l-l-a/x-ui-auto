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

# Detect OS
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
else
    echo "Cannot detect OS"; exit 1
fi

install_base() {
    case "$release" in
        ubuntu|debian) apt update && apt install -y wget curl tar tzdata ;;
        centos|rhel|almalinux|rocky) yum install -y wget curl tar tzdata ;;
        *) apt update && apt install -y wget curl tar tzdata ;;
    esac
}

install_xui() {
    echo -e "${green}Installing X-UI ...${plain}"
    cd /usr/local/

    tag=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" \
        | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    [[ -z "$tag" ]] && echo "Cannot fetch version" && exit 1

    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64|arm64) FILE="x-ui-linux-arm64.tar.gz" ;;
        x86_64) FILE="x-ui-linux-amd64.tar.gz" ;;
        *) FILE="x-ui-linux-amd64.tar.gz" ;;
    esac

    wget -O x-ui.tar.gz \
        https://github.com/MHSanaei/3x-ui/releases/download/${tag}/${FILE} \
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
    echo -e "${green}Applying clean database ...${plain}"
    mkdir -p /etc/x-ui/

    wget -O /etc/x-ui/x-ui.db \
        https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/x-ui.db \
        || exit 1

    x-ui restart
}

############ RUN INSTALLATION ############
install_base
install_xui
replace_database

mkdir -p /etc/x-ui/configs/

############################################
### 1) VLESS : 80 (ID ثابت = 80)
############################################
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
  "path": "/"
}
EOF

############################################
### 2) TROJAN : 8080 (پسورد ثابت = qFjldybtd2)
############################################
cat <<EOF >/etc/x-ui/configs/trojan_8080.json
{
  "protocol": "trojan",
  "password": "qFjldybtd2",
  "address": "$DOMAIN",
  "port": 8080,
  "network": "ws",
  "path": "/",
  "security": "none"
}
EOF

##########################
### Output
##########################
echo -e "${green}"
echo "=========== LINKS FOR $DOMAIN =========="

echo ""
echo "🔹 VLESS 80:"
echo "vless://80@$DOMAIN:80?type=ws&encryption=none&path=%2F&security=none#80-80"

echo ""
echo "🔹 TROJAN 8080:"
echo "trojan://qFjldybtd2@$DOMAIN:8080?type=ws&path=%2F&security=none#8080-nxix5u1l"

echo ""
echo "========================================="
echo -e "${plain}"
