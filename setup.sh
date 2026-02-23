#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}Run as root${plain}" && exit 1

DOMAIN="$1"
if [[ -z "$DOMAIN" ]]; then
    echo -e "${red}Usage:${plain} bash setup.sh yourdomain.com"
    exit 1
fi

# Firewall setup
apt -y install ufw
ufw allow 22
ufw allow 80
ufw allow 8080
ufw allow 2095
echo "y" | ufw disable
echo "y" | ufw enable
ufw reload
ufw status numbered

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
        fedora) dnf install -y wget curl tar tzdata ;;
        alpine) apk add --no-cache wget curl tar tzdata ;;
        *) apt update && apt install -y wget curl tar tzdata ;;
    esac
}

get_arch() {
    case "$(uname -m)" in
        x86_64|x64|amd64) echo "amd64" ;;
        i*86|x86) echo "386" ;;
        aarch64|arm64|armv8*) echo "arm64" ;;
        armv7*|armv7) echo "armv7" ;;
        armv6*|armv6) echo "armv6" ;;
        armv5*|armv5) echo "armv5" ;;
        s390x) echo "s390x" ;;
        *) echo "amd64" ;; # fallback
    esac
}

install_xui() {
    echo -e "${green}Installing X-UI...${plain}"
    cd /usr/local/ || exit 1

    tag=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "$tag" ]] && echo "Cannot fetch version" && exit 1

    ARCH=$(get_arch)
    FILE="x-ui-linux-${ARCH}.tar.gz"

    wget -O x-ui.tar.gz "https://github.com/MHSanaei/3x-ui/releases/download/${tag}/${FILE}" || exit 1

    systemctl stop x-ui 2>/dev/null
    rm -rf /usr/local/x-ui

    tar -xzf x-ui.tar.gz
    rm -f x-ui.tar.gz

    cd x-ui
    chmod +x x-ui x-ui.sh bin/*

    # Install service
    if [[ -f x-ui.service ]]; then
        cp -f x-ui.service /etc/systemd/system/
    else
        # fallback: download service based on OS
        case "$release" in
            ubuntu|debian) curl -sL -o /etc/systemd/system/x-ui.service https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.debian ;;
            *) curl -sL -o /etc/systemd/system/x-ui.service https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.rhel ;;
        esac
    fi

    mv -f x-ui.sh /usr/bin/x-ui
    chmod +x /usr/bin/x-ui

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
}

replace_database() {
    echo -e "${green}Applying clean database...${plain}"
    local DB_DIR="/etc/x-ui"
    local DB_FILE="x-ui.db"
    local DB_URL="https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/no-warp-x-ui.db"
    mkdir -p "$DB_DIR" || exit 1
    wget -q -O "$DB_DIR/$DB_FILE" "$DB_URL" || exit 1
    x-ui restart
}

############ RUN INSTALLATION ############
install_base
install_xui
replace_database

mkdir -p /etc/x-ui/configs/

############################################
### VLESS 80
############################################
cat <<EOF >/root/vless_80.json
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
### TROJAN 8080
############################################
cat <<EOF >/root/trojan_8080.json
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

############################################
cat <<EOF >/root/vless.txt
vless://80@$DOMAIN:80?type=ws&encryption=none&path=%2F&security=none#80-80
EOF

cat <<EOF >/root/trojan.txt
trojan://qFjldybtd2@$DOMAIN:8080?type=ws&path=%2F&security=none#8080-nxix5u1l
EOF

##########################
### Output
##########################
echo -e "${green}"
echo "=========== LINKS FOR $DOMAIN =========="
echo ""
echo "🔹 VLESS 80:"
echo "vless://80@${DOMAIN}:80?type=tcp&encryption=none&path=%2F&host=google.com&headerType=http&security=none#80-${DOMAIN}"
echo ""
echo "🔹 TROJAN 8080:"
echo "trojan://qFjldybtd2@$DOMAIN:8080?type=ws&path=%2F&security=none#8080-nxix5u1l"
echo ""
echo "========================================="
echo -e "${plain}"
