# نصب WARP
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update && sudo apt-get install -y cloudflare-warp

# ثبت‌نام با ارسال خودکار 'y' به prompt
printf "y\n" | warp-cli registration new

# مود پروکسی و پورت
warp-cli mode proxy
warp-cli proxy port 4848
warp-cli connect

# بررسی وضعیت
warp-cli status
