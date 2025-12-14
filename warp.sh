#!/bin/bash
set -e

green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0;31m'
plain='\033[0m'

echo -e "${green}Installing dependencies...${plain}"
apt update
apt install -y curl gpg apt-transport-https expect util-linux

echo -e "${green}Installing Cloudflare WARP...${plain}"
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor \
    -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

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

# TTY واقعی + expect (تنها روش قطعی)
script -q -c "expect << 'EOF'
spawn warp-cli registration new
expect {
    \"Accept Terms of Service\" {
        send \"y\r\"
        exp_continue
    }
    eof
}
EOF" /dev/null

sleep 2

echo -e "${green}Applying license if available...${plain}"
LICENSES=$(curl -s https://raw.githubusercontent.com/o-k-l-l-a/x-ui-auto/refs/heads/main/license.txt | tr -d '\r' | grep -v '^$')

for lic in \$LICENSES; do
    if warp-cli registration license \"\$lic\" >/dev/null 2>&1; then
        echo -e \"${green}License applied: \$lic${plain}\"
        break
    fi
done

echo -e "${green}Setting Proxy mode (port 4848)...${plain}"
warp-cli mode proxy
warp-cli proxy port 4848

echo -e "${green}Connecting WARP...${plain}"
warp-cli connect

echo -e "${green}Final status:${plain}"
warp-cli status
