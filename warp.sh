#!/bin/bash
set -e

# رنگ‌ها برای نمایش بهتر
green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0;31m'
plain='\033[0m'

echo -e "${green}Installing dependencies...${plain}"
apt update
apt install -y curl gpg apt-transport-https expect

echo -e "${green}Installing Cloudflare WARP...${plain}"
# اضافه کردن کلید و مخزن
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" \
> /etc/apt/sources.list.d/cloudflare-client.list

apt update
apt install -y cloudflare-warp

echo -e "${green}Starting WARP daemon...${plain}"
systemctl enable --now warp-svc
sleep 5

echo -e "${green}Deleting old registration...${plain}"
warp-cli registration delete || true
sleep 2

echo -e "${green}Creating new registration (auto-accept ToS)...${plain}"
expect << 'EOF'
spawn warp-cli registration new
expect "Accept Terms of Service"
send "y\r"
expect eof
EOF
sleep 2

# گرفتن لیست لایسنس‌ها
LICENSES=$(curl -s https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/license.txt | tr -d '\r' | grep -v '^$')
VALID_LICENSE=""

echo -e "${green}Applying licenses...${plain}"
for lic in $LICENSES; do
    if warp-cli registration license "$lic" >/dev/null 2>&1; then
        echo -e "${green}License applied successfully: $lic${plain}"
        VALID_LICENSE="$lic"
        break
    else
        echo -e "${yellow}License failed, trying next...${plain}"
    fi
done

if [[ -z "$VALID_LICENSE" ]]; then
    echo -e "${yellow}No valid license found → Using Free registration${plain}"
fi

echo -e "${green}Setting Proxy mode and port 4848...${plain}"
warp-cli mode proxy
warp-cli proxy port 4848

echo -e "${green}Connecting WARP...${plain}"
warp-cli connect
warp-cli status
