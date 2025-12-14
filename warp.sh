#!/bin/bash
set -e

green='\033[0;32m'
red='\033[0;31m'
plain='\033[0m'

echo -e "${green}Installing Cloudflare WARP...${plain}"

# نصب WARP
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update
sudo apt-get install -y cloudflare-warp

# Start سرویس WARP
echo -e "${green}Starting WARP daemon...${plain}"
sudo systemctl enable --now warp-svc
sleep 2

# حذف رجیستری قدیمی
echo -e "${green}Deleting old registration...${plain}"
sudo warp-cli registration delete || true

# رجیستر اولیه بدون لایسنس
printf "y\n" | warp-cli registration new

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
        echo -e "${yellow}Trying license...${plain}"
    fi
done

# اگر هیچ لایسنسی valid نبود → Free registration
if [[ -z "$VALID_LICENSE" ]]; then
    echo -e "${red}No valid license found. Switching to Free registration...${plain}"
    sudo warp-cli registration delete || true
    printf "y\n" | warp-cli registration new
fi

# ست کردن مود Proxy و پورت
echo -e "${green}Setting Proxy mode and port 4848...${plain}"
warp-cli mode proxy
warp-cli proxy port 4848

# کانکت و نمایش وضعیت
warp-cli connect
warp-cli status
