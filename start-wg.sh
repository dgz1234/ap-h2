#!/bin/sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

WG_CONF="/etc/wireguard/wg0.conf"
mkdir -p /etc/wireguard

echo "${GREEN}[0/5] 安装 wireguard-tools 依赖...${NC}"
apk add --no-cache wireguard-tools

echo "${GREEN}[1/5] 检查 WireGuard 内核模块...${NC}"
if ! lsmod | grep -q wireguard; then
    echo "${RED}× 未检测到 WireGuard 内核模块，脚本退出${NC}"
    exit 1
fi

echo "${GREEN}[2/5] 生成私钥和公钥...${NC}"
PRIVATE_KEY=$(wg genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)

echo "${YELLOW}私钥：$PRIVATE_KEY${NC}"
echo "${YELLOW}公钥：$PUBLIC_KEY${NC}"

echo "${GREEN}[3/5] 写入配置文件到 $WG_CONF...${NC}"
cat > "$WG_CONF" <<EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 172.16.0.2/32, 2606:4700:110:8da4:c505:b2c:f503:c10b/128
MTU = 1280
# DNS = 1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0
Endpoint = engage.cloudflareclient.com:2408
EOF

chmod 600 "$WG_CONF"

echo "${GREEN}[4/5] 启动 WireGuard 接口...${NC}"
if wg-quick up wg0; then
    echo "${GREEN}√ WireGuard 启动成功${NC}"
else
    echo "${RED}× 启动失败，请检查配置${NC}"
    exit 1
fi
