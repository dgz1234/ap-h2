#!/bin/sh
# █ Alpine WARP 智能注册版 █
# 自动检测账户状态 | 2024-07-20

# >>>>> 用户配置区 <<<<<
SSH_IP="2001:41d0:303:3e79:be24:11ff:fe7c:6302"  # 修改为您的真实SSH IP
WARP_LOCK="2606:4700:d0::a29f:c001"              # Cloudflare IPv6端点

# ███ 账户状态检查 ███
check_account() {
    echo "🔍 检查WARP账户状态..."
    if [ -f "/etc/wireguard/accounts/wgcf-account.toml" ]; then
        if wgcf status | grep -q "Account type: free"; then
            echo "✅ 检测到有效免费账户"
            return 0
        elif wgcf status | grep -q "Account type: paid"; then
            echo "💳 检测到有效付费账户"
            return 0
        fi
    fi
    return 1
}

# ███ 账户注册 ███
register_warp() {
    echo "🔐 开始注册WARP账户..."
    for i in 1 2 3; do
        if wgcf register --accept-tos; then
            echo "🎉 账户注册成功"
            return 0
        fi
        echo "⚠️ 第$i次尝试失败，等待10秒..."
        sleep 10
    done
    echo "❌ 账户注册失败！请检查："
    echo "1. 网络连接状态"
    echo "2. 手动执行: WG_DEBUG=1 wgcf register --accept-tos"
    exit 1
}

# ███ 配置生成 ███
generate_config() {
    echo "🛠️ 生成WireGuard配置..."
    wgcf generate
    
    # 修复IPv6排除问题
    sed -i "
        s|engage.cloudflareclient.com|[$WARP_LOCK]|;
        /\[Peer\]/a PostUp = ip -6 route add $SSH_IP dev eth0
    " wgcf-profile.conf
    
    # 确保主路由表正常
    echo "PostDown = ip -6 route del $SSH_IP" >> wgcf-profile.conf
}

# ███ 主流程 ███
set -e
echo "🚀 初始化系统..."
echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
apk update && apk add --no-cache wgcf wireguard-tools

check_account || register_warp
generate_config

echo "🔗 启动WARP隧道..."
wg-quick up ./wgcf-profile.conf

# ███ 验证 ███
echo -e "\n✅ 部署成功！验证信息："
echo "IPv4出口: $(curl -4s ifconfig.me)"
echo "账户状态: $(wgcf status | grep "Account type")"
wg show