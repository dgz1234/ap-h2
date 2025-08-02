#!/bin/sh
# █ Alpine WARP 终极脚本 █
# 修正版 2024-07-20 | 已修复换行符问题

# >>>>> 用户配置区 <<<<<
SSH_IP="2001:41d0:303:3e79:be24:11ff:fe7c:6302"  # 您的SSH服务器IPv6
WARP_LICENSE_KEY=""                               # 可选付费License Key
WARP_LOCK="2606:4700:d0::a29f:c001"              # Cloudflare IPv6端点

# ███ 核心函数 ███
register_warp() {
    echo "🔐 正在申请WARP免费账户..."
    for i in 1 2 3; do
        if wgcf register --accept-tos; then
            return 0
        fi
        echo "⚠️ 第$i次注册失败，30秒后重试..."
        sleep 30
    done
    echo "❌ 账户注册失败！请检查网络后重试"
    exit 1
}

create_tunnel() {
    echo "🛠️ 生成WireGuard配置..."
    wgcf generate
    sed -i "
        s|engage.cloudflareclient.com|[$WARP_LOCK]|;
        /\[Peer\]/,/AllowedIPs/s|0.0.0.0/0|0.0.0.0/0,!$SSH_IP/128|;
        /PersistentKeepalive/a Table = off
    " wgcf-profile.conf
}

# ███ 主流程 ███
set -e
echo "🚀 正在安装依赖..."
apk add --no-cache wgcf wireguard-tools || {
    echo "⚠️ 默认源失败，启用Edge源..."
    apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main wgcf wireguard-tools
}

[ -f "/etc/wireguard/accounts/wgcf-account.toml" ] || register_warp
create_tunnel

echo "🔗 启动WARP隧道..."
wg-quick up ./wgcf-profile.conf

# ███ 验证 ███
echo -e "\n✅ 部署成功！验证信息："
echo "IPv4出口: $(curl -4s ifconfig.me)"
echo "IPv6路由测试:"
ip -6 route get "$SSH_IP" | awk '{print "通过网卡:",$3,"| 网关:",$5}'
wg show

cat <<EOF

💡 使用说明：
1. 状态检查: wg show
2. 临时关闭: wg-quick down ./wgcf-profile.conf
3. 完全卸载: rm wgcf-* && apk del wgcf wireguard-tools
EOF