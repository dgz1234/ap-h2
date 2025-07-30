#!/bin/bash

# 安装WARP官方客户端
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
apt update && apt install -y cloudflare-warp

# 自动注册（无交互）
warp-cli --accept-tos register
warp-cli set-mode proxy
warp-cli connect

# 验证连接
sleep 5
if warp-cli status | grep -q "Connected"; then
    echo "WARP 已启用"
    echo "SOCKS5代理地址: 127.0.0.1:40000"
else
    echo "WARP 连接失败，请手动检查: warp-cli status"
    exit 1
fi

# 使用代理下载示例（如Hysteria）
curl --socks5 127.0.0.1:40000 -LO https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
chmod +x hysteria-linux-amd64