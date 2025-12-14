#!/bin/bash
set -e

green='\033[0;32m'
red='\033[0;31m'
plain='\033[0m'

# نصب Cloudflare WARP
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update -qq
sudo apt-get install -y cloudflare-warp >/dev/null 2>&1

# start daemon
sudo systemctl enable --now warp-svc >/dev/null 2>&1
sleep 2

# حذف رجیستری قدیمی
sudo warp-cli registration delete >/dev/null 2>&1 || true

# رجیستر اولیه Free برای آماده سازی
printf "y\n" | warp-cli registration new >/dev/null 2>&1

# گرفتن لیست لایسنس‌ها
LICENSES=$(curl -s https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/license.txt | tr -d '\r' | grep -v '^$')
LICENSE_APPLIED=false

for lic in $LICENSES; do
    if warp-cli registration license "$lic" >/dev/null 2>&1; then
        echo -e "${green}License applied successfully${plain}"
        LICENSE_APPLIED=true
        break
    fi
done

# اگر هیچ لایسنسی valid نبود → Free registration
if [ "$LICENSE_APPLIED" = false ]; then
    sudo warp-cli registration delete >/dev/null 2>&1 || true
    printf "y\n" | warp-cli registration new >/dev/null 2>&1
fi

# ست کردن مود Proxy و پورت
warp-cli mode proxy >/dev/null 2>&1
warp-cli proxy port 4848 >/dev/null 2>&1
warp-cli connect >/dev/null 2>&1

# نمایش فقط وضعیت نهایی
echo -e "${green}WARP setup completed.${plain}"
