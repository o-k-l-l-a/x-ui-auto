#!/bin/bash

########################
# Cleanup old output files
########################
rm -f /root/vless_*
rm -f /root/trojan_*
rm -f /root/*.json
rm -f /root/domin*.txt

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
echo "y" | x-ui uninstall 2>/dev/null
echo "y" | warp u 2>/dev/null

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
# Detect OS
########################
source /etc/os-release
release=$ID

install_base() {
    case "$release" in
        ubuntu|debian) apt install -y wget curl tar tzdata ;; 
        centos|rhel|almalinux|rocky) yum install -y wget curl tar tzdata ;;
        fedora) dnf install -y wget curl tar tzdata ;;
        alpine) apk add --no-cache wget curl tar tzdata ;;
        *) apt install -y wget curl tar tzdata ;;
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

########################
# Install X-UI
########################
install_xui() {
    echo -e "${green}Installing X-UI ...${plain}"
    cd /usr/local || exit 1

    tag=$(curl -Ls https://api.github.com/repos/MHSanaei/3x-ui/releases/latest \
        | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    [[ -z "$tag" ]] && echo "Cannot fetch version" && exit 1

    ARCH=$(get_arch)
    FILE="x-ui-linux-${ARCH}.tar.gz"

    wget -O x-ui.tar.gz \
      "https://github.com/MHSanaei/3x-ui/releases/download/${tag}/${FILE}" || exit 1

    systemctl stop x-ui 2>/dev/null
    rm -rf /usr/local/x-ui

    tar -xzf x-ui.tar.gz
    rm -f x-ui.tar.gz

    cd x-ui || exit 1
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

########################
# Replace DB
########################
replace_database() {
    local DB_DIR="/etc/x-ui"
    local DB_FILE="x-ui.db"
    local DB_URL="https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/no-warp-x-ui.db"

    mkdir -p "$DB_DIR" || exit 1
    wget -q -O "$DB_DIR/$DB_FILE" "$DB_URL" || exit 1

    x-ui restart
}

install_base
install_xui
replace_database

########################
# Create VLESS txt files
########################
i=1
for DOMAIN in "${DOMAINS[@]}"; do
cat <<EOF >/root/domin${i}.txt
vless://80@${DOMAIN}:80?path=%2F&security=none&fragment=90-250%2C10-100%2C1-3&encryption=none&type=ws#80-${DOMAIN}
EOF
((i++))
done

########################
# Cleanup intermediate files
########################
rm -f /root/vless_*
rm -f /root/trojan_*
rm -f /root/*.json

########################
# Output
########################
echo -e "${green}"
echo "=========== DONE =========="
echo "Created files:"
ls /root/domin*.txt
echo "==========================="
echo -e "${plain}"
