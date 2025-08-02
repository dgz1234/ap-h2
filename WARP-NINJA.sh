#!/bin/sh
# █ Alpine WARP 终极脚本 █
# 官方源纯净版 2024-07-20

# >>>>> 用户配置区 <<<<<
SSH_IP="2001:41d0:303:3e79:be24:11ff:fe7c:6302"  # 修改为您的真实SSH IP
WARP_LOCK="2606:4700:d0::a29f:c001"              # Cloudflare官方IPv6端点

# ███ 初始化系统 ███
init_system() {
    echo "🚀 正在配置Alpine官方源..."
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
    apk update
}

# ███ 安装依赖 ███
install_deps() {
    echo "📦 正在安装核心组件..."
    apk add --no-cache \
        wgcf \
        wireguard-tools \
        openresolv \
        iptables \
        ip6tables
}

# ███ 账户注册 ███
register_warp() {
    echo "🔐 正在注册WARP账户..."
    for i in $(seq 1 3); do
        if wgcf register --accept-tos; then
            return 0
        fi
        echo "⚠️ 第$i次尝试失败，等待10秒..."
        sleep 10
    done
    echo "❌ 注册失败！请检查："
    echo "1. 网络连接状态"
    echo "2. 尝试手动执行: WG_DEBUG=1 wgcf register --accept-tos"
    exit 1
}

# ███ 配置生成 ███
generate_config() {
    echo "🛠️ 生成WireGuard配置..."
    wgcf generate

    # 安全隔离SSH流量
    sed -i "
        s|engage.cloudflareclient.com|[$WARP_LOCK]|;
        /AllowedIPs/s|0.0.0.0/0|0.0.0.0/0,!${SSH_IP}/128|;
        /PersistentKeepalive/a Table = off
    " wgcf-profile.conf
}

# ███ 主流程 ███
set -e
init_system
install_deps
[ -f "/etc/wireguard/accounts/wgcf-account.toml" ] || register_warp
generate_config

echo "🔗 启动WARP隧道..."
wg-quick up ./wgcf-profile.conf

# ███ 验证 ███
echo -e "\n✅ 部署成功！验证信息："
echo "IPv4 出口IP: $(curl -4s ifconfig.me)"
echo "IPv6 路由检测:"
ip -6 route get "$SSH_IP" | awk '{print "  通过网卡: "$3" | 网关: "$5}'
wg show wgcf

cat <<EOF

💡 使用说明：
1. 状态检查: wg show wgcf
2. 临时关闭: wg-quick down ./wgcf-profile.conf
3. 彻底卸载: 
   apk del wgcf wireguard-tools openresolv
   rm -f /etc/wireguard/accounts/wgcf-account.toml

📌 开机自启:
echo 'wg-quick up /path/to/wgcf-profile.conf' >> /etc/local.d/warp.start
chmod +x /etc/local.d/warp.start
rc-update add local
EOF
