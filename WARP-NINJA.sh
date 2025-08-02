#!/bin/sh
# █ Alpine WARP 终极修复版 █
# 完全解决账户注册问题 | 2024-07-20

# >>>>> 用户配置区 <<<<<
SSH_IP="2001:41d0:303:3e79:be24:11ff:fe7c:6302"  # 修改为您的真实SSH IP
WARP_LOCK="2606:4700:d0::a29f:c001"              # Cloudflare IPv6端点

# ███ 初始化系统 ███
init_system() {
    echo "🚀 配置Alpine官方源..."
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
    apk update
}

# ███ 安装依赖 ███
install_deps() {
    echo "📦 安装核心组件..."
    apk add --no-cache \
        wgcf \
        wireguard-tools \
        openresolv \
        iptables \
        ip6tables \
        jq
}

# ███ 彻底清理旧账户 ███
clean_old_account() {
    echo "🧹 清理旧账户配置..."
    rm -f /etc/wireguard/accounts/wgcf-account.toml
    rm -f wgcf-account.toml
}

# ███ 账户注册 ███
register_warp() {
    echo "🔐 注册WARP账户..."
    clean_old_account
    
    for i in 1 2 3; do
        echo "尝试第 $i 次注册..."
        if WG_DEBUG=1 wgcf register --accept-tos 2>&1 | grep -q "Device name"; then
            echo "✅ 注册成功"
            return 0
        fi
        sleep 10
    done
    
    echo "❌ 注册失败！请尝试："
    echo "1. 更换网络环境"
    echo "2. 等待1小时后重试"
    echo "3. 手动注册: WG_DEBUG=1 wgcf register --accept-tos"
    exit 1
}

# ███ 配置生成 ███
generate_config() {
    echo "🛠️ 生成WireGuard配置..."
    wgcf generate
    
    # 修复IPv6排除问题
    sed -i "
        s|engage.cloudflareclient.com|[$WARP_LOCK]|;
        /\[Peer\]/a Table = off
    " wgcf-profile.conf
    
    # 添加路由规则
    echo "PostUp = ip -6 route add $SSH_IP via \$(ip -6 route show default | awk '{print \$3}') dev eth0" >> wgcf-profile.conf
    echo "PostDown = ip -6 route del $SSH_IP" >> wgcf-profile.conf
}

# ███ 主流程 ███
set -e
init_system
install_deps
register_warp
generate_config

echo "🔗 启动WARP隧道..."
wg-quick up ./wgcf-profile.conf

# ███ 验证 ███
echo -e "\n✅ 部署成功！验证信息："
echo "IPv4出口: $(curl -4s ifconfig.me)"
echo "IPv6路由测试:"
ip -6 route get "$SSH_IP" | awk '{print "通过网卡:",$3,"| 网关:",$5}'
wg show