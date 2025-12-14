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

# شروع سرویس (اگر اجرا نشده)
sudo systemctl enable --now warp-svc
sleep 2

# توقف و حذف رجیستری قدیمی
sudo warp-cli disconnect || true
sudo warp-cli registration delete || true

# رجیستر جدید
printf "y\n" | warp-cli registration new

# لیسنس‌ها
LICENSES=$(curl -s https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/license.txt | tr -d '\r' | grep -v '^$')
VALID_LICENSE=""
for lic in $LICENSES; do
    if warp-cli registration license "$lic" >/dev/null 2>&1; then
        echo -e "${green}License applied successfully: $lic${plain}"
        VALID_LICENSE="$lic"
        break
    fi
done

# اگر هیچ لایسنسی valid نبود → Free registration
if [[ -z "$VALID_LICENSE" ]]; then
    printf "y\n" | warp-cli registration new
fi

# Proxy mode و پورت
warp-cli mode proxy
warp-cli proxy port 4848

# کانکت
warp-cli connect
warp-cli status
