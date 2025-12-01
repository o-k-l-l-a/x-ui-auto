#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

# Root check
[[ $EUID -ne 0 ]] && echo -e "${red}Please run as root${plain}" && exit 1

# Detect OS
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
else
    echo "Cannot detect OS!"
    exit 1
fi

# Detect public IPv4
PUBLIC_IP=$(curl -s ipv4.icanhazip.com)
if [[ -z "$PUBLIC_IP" ]]; then
    echo -e "${red}Cannot detect public IPv4!${plain}"
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

# ------------------------
#      RUN ALL
# ------------------------
install_base
install_xui
replace_database

# Print Access Info
echo -e "${green}"
echo "Access URL: http://$PUBLIC_IP:2053/amin/"
echo ""
echo "========= ACCOUNTS ========="
echo ""

echo "vless://60d89805-faa6-44c0-b027-95c0680a7ddb@$PUBLIC_IP:2083?type=xhttp&encryption=none&path=%2F&host=&mode=auto&security=tls&fp=randomized&alpn=h2%2Chttp%2F1.1&allowInsecure=1&sni=test.ostabat.ir#2083-gxdpyrpt"
echo ""
echo "vless://7f601407-602e-4299-8ed8-30f7dc799c4c@$PUBLIC_IP:2087?type=ws&encryption=none&path=%2F&host=&security=tls&fp=randomized&alpn=h2%2Chttp%2F1.1&allowInsecure=1&sni=test.ostabat.ir#2087-82t5utox"
echo ""
echo "trojan://lQcb30owdu@$PUBLIC_IP:8443?type=grpc&serviceName=&authority=&security=tls&fp=randomized&alpn=h2%2Chttp%2F1.1&allowInsecure=1&sni=test.ostabat.ir#8443-pogl1715"
echo ""
echo "vmess://ewogICJ2IjogIjIiLAogICJwcyI6ICI0NDMtMHpmeG5vM2UiLAogICJhZGQiOiAi$PUBLIC_IPIiwKICAicG9ydCI6IDQ0MywKICAiaWQiOiAiOTdmMTdlNTctYTNjNC00ZWMxLTgwMDAtZThhMTFhMzUxMTkzIiwKICAic2N5IjogImF1dG8iLAogICJuZXQiOiAieGh0dHAiLAogICJ0bHMiOiAidGxzIiwKICAicGF0aCI6ICIvIiwKICAiaG9zdCI6ICIiLAogICJ0eXBlIjogImF1dG8iLAogICJzbmkiOiAidGVzdC5vc3RhYmF0LmlyIiwKICAiZnAiOiAicmFuZG9taXplZCIsCiAgImFscG4iOiAiaDIsaHR0cC8xLjEiLAogICJhbGxvd0luc2VjdXJlIjogdHJ1ZQp9"
echo ""
echo "============================"
echo -e "${plain}"
