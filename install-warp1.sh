#!/bin/bash
# ==============================================
# Alpine Linux 极简WARP配置脚本
# 功能：一键配置WireGuard形式的WARP代理
# 依赖：wireguard-tools, curl
# ==============================================

# 常量定义
CONFIG_FILE="/etc/wireguard/wgcf.conf"
CF_PUBLIC_KEY="bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="
CF_ENDPOINT="[2606:4700:d0::a29f:c001]:2408"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查并安装依赖
install_deps() {
    if ! command -v wg-quick >/dev/null; then
        echo -e "${YELLOW}正在安装 wireguard-tools...${NC}"
        apk add --no-cache wireguard-tools || {
            echo -e "${RED}安装失败！请检查：${NC}"
            echo "1. 确保已启用Alpine的community仓库"
            echo "2. 手动运行: apk update && apk add wireguard-tools"
            exit 1
        }
    fi
}

# 生成配置
generate_config() {
    cat > "$CONFIG_FILE" <<EOF
[Interface]
PrivateKey = $(wg genkey)
Address = 172.16.0.2/32
# DNS = 1.1.1.1, 2606:4700:4700::1111
MTU = 1280

[Peer]
PublicKey = $CF_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = $CF_ENDPOINT
PersistentKeepalive = 25
EOF
}

# 主流程
install_deps
generate_config

wg-quick up wgcf && {
    echo -e "\n${GREEN}✅ WARP 启动成功${NC}"
    echo -e "IPv4地址: $(curl -4 --interface wgcf ifconfig.co 2>/dev/null || echo "检测失败")"
    echo -e "接口状态:\n$(wg show wgcf)"
} || {
    echo -e "\n${RED}❌ 启动失败，可能原因：${NC}"
    echo "1. 内核未加载wireguard模块（尝试: modprobe wireguard）"
    echo "2. LXC容器权限不足（需宿主机运行: lxc config set 容器名 security.privileged true）"
    exit 1
}