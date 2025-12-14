#!/bin/bash
set -e

# Colors
green='\033[0;32m'
red='\033[0;31m'
plain='\033[0m'

echo -e "${green}Installing Cloudflare WARP...${plain}"

# نصب WARP
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update
sudo apt-get install -y cloudflare-warp

# حذف رجیستری قبلی اگر موجود باشد
if warp-cli registration show >/dev/null 2>&1; then
    echo -e "${red}Existing registration found. Deleting...${plain}"
    warp-cli registration delete || true
fi

# رجیستر جدید (silent)
printf "y\n" | warp-cli registration new

# دانلود لیست لایسنس‌ها
LICENSES=$(curl -s https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/license.txt | tr -d '\r' | grep -v '^$')

VALID_LICENSE=""

echo -e "${green}Trying licenses...${plain}"
for lic in $LICENSES; do
    if warp-cli registration license "$lic" 2>/dev/null; then
        echo -e "${green}License applied successfully: $lic${plain}"
        VALID_LICENSE="$lic"
        break
    else
        echo -e "${red}License failed: $lic${plain}"
    fi
done

# اگر هیچ لایسنسی اوکی نبود → Free registration
if [[ -z "$VALID_LICENSE" ]]; then
    echo -e "${red}No valid license found. Switching to Free registration...${plain}"
    warp-cli registration delete || true
    printf "y\n" | warp-cli registration new
fi

# Proxy mode + پورت
warp-cli mode proxy
warp-cli proxy port 4848

# اتصال
warp-cli connect

# نمایش وضعیت
warp-cli status
