#!/bin/bash

NEW_IP="YOUR_PUBLIC_IP"

red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}Please run as root${plain}" && exit 1

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
else
    echo "Cannot detect OS!"
    exit 1
fi

arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) echo "Unsupported arch"; exit 1 ;;
    esac
}

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
        https://github.com/MHSanaei/3x-ui/releases/download/${tag}/x-ui-linux-$(arch).tar.gz \
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

install_base
install_xui
replace_database

echo -e "${green}"
echo "Access URL: http://${NEW_IP}:2053/amin/"
echo ""
echo "========= ACCOUNTS ========="
echo ""
echo "vless://60d89805-faa6-44c0-b027-95c0680a7ddb@${NEW_IP}:2083?type=xhttp&encryption=none&path=%2F&host=&mode=auto&security=tls&fp=randomized&alpn=h2%2Chttp%2F1.1&allowInsecure=1&sni=test.ostabat.ir#2083-gxdpyrpt"
echo ""
echo "vless://7f601407-602e-4299-8ed8-30f7dc799c4c@${NEW_IP}:2087?type=ws&encryption=none&path=%2F&host=&security=tls&fp=randomized&alpn=h2%2Chttp%2F1.1&allowInsecure=1&sni=test.ostabat.ir#2087-82t5utox"
echo ""
echo "trojan://lQcb30owdu@${NEW_IP}:8443?type=grpc&serviceName=&authority=&security=tls&fp=randomized&alpn=h2%2Chttp%2F1.1&allowInsecure=1&sni=test.ostabat.ir#8443-pogl1715"
echo ""
echo "vmess://$(echo -n '{
  "v": "2",
  "ps": "443-0zfxno3e",
  "add": "'${NEW_IP}'",
  "port": 443,
  "id": "97f17e57-a3c4-4ec1-8000-e8a11a351193",
  "scy": "auto",
  "net": "xhttp",
  "tls": "tls",
  "path": "/",
  "host": "",
  "type": "auto",
  "sni": "test.ostabat.ir",
  "fp": "randomized",
  "alpn": "h2,http/1.1",
  "allowInsecure": true
}' | base64)"
echo ""
echo "============================"
echo -e "${plain}"
