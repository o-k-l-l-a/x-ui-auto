
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update && sudo apt-get install -y cloudflare-warp

printf "y\n" | warp-cli registration new
warp-cli registration license c1l9y72z-V2c3Gk09-7A3Ft9K6
warp-cli mode proxy
warp-cli proxy port 4848
warp-cli connect

warp-cli status
