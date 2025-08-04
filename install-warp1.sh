#!/bin/bash
# ==============================================
# Alpine WARP配置脚本（容器优化版）
# 修复：内核模块/DNS/Endpoint兼容性问题
# ==============================================

# 安装依赖（容器优化版）
install_deps() {
    apk add --no-cache wireguard-tools iptables ip6tables curl linux-lts-headers || {
        echo -e "\033[31m依赖安装失败！请检查网络或手动执行："
        echo "apk update && apk add wireguard-tools iptables ip6tables linux-lts-headers"
        exit 1
    }
    
    # LXC容器内核模块处理
    [ ! -d "/lib/modules" ] && \
    mkdir -p /lib/modules && \
    ln -s /usr/src/linux-headers-$(uname -r) /lib/modules/$(uname -r) 2>/dev/null
    
    modprobe wireguard || echo -e "\033[33m⚠ 容器可能需宿主机加载模块"
}

# 生成配置（自动选择最优Endpoint）
generate_config() {
    CF_ENDPOINT=$(
        ping -c 1 -W 1 2606:4700:d0::a29f:c001 &>/dev/null && \
        echo "[2606:4700:d0::a29f:c001]:2408" || echo "162.159.193.10:2408"
    )
    
    cat > /etc/wireguard/wgcf.conf <<EOF
[Interface]
PrivateKey = $(wg genkey)
Address = 172.16.0.2/32
# DNS = 1.1.1.1
MTU = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0
Endpoint = $CF_ENDPOINT
PersistentKeepalive = 25
EOF
}

# 主流程
install_deps
generate_config

wg-quick up wgcf && {
    echo -e "\033[32m✅ WireGuard接口已启动"
    echo -e "ℹ️ 测试IPv4连通性（可能需等待1-2分钟）..."
    
    # 更可靠的测试方法
    if timeout 60 ping -c 3 -I wgcf 1.1.1.1; then
        echo -e "\033[32m✔ 网络连接正常"
    else
        echo -e "\033[33m⚠ 能启动但无流量，请尝试："
        echo "1. 更换Endpoint: sed -i 's|Endpoint = .*|Endpoint = 162.159.193.10:2408|' /etc/wireguard/wgcf.conf"
        echo "2. 检查DNS: echo 'nameserver 1.1.1.1' > /etc/resolv.conf"
    fi
} || {
    echo -e "\033[31m❌ 启动失败，请检查："
    echo "1. 容器权限: lxc config set 容器名 security.privileged true"
    echo "2. 宿主加载模块: modprobe wireguard"
    exit 1
}