#!/bin/bash
# ==============================================
# Alpine Linux WARP 自动配置脚本（修复版）
# 修复问题：iptables缺失、内核模块加载
# ==============================================

# 安装核心依赖
install_deps() {
    apk add --no-cache wireguard-tools iptables ip6tables || {
        echo -e "\033[31m依赖安装失败！请手动执行："
        echo "apk update && apk add wireguard-tools iptables ip6tables"
        exit 1
    }
    modprobe wireguard || echo -e "\033[33m⚠ 警告：无法自动加载wireguard模块，请检查内核配置"
}

# 生成配置
generate_config() {
    cat > /etc/wireguard/wgcf.conf <<EOF
[Interface]
PrivateKey = $(wg genkey)
Address = 172.16.0.2/32
# DNS = 1.1.1.1
MTU = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0
Endpoint = [2606:4700:d0::a29f:c001]:2408
PersistentKeepalive = 25
EOF
}

# 主流程
install_deps
generate_config

wg-quick up wgcf && {
    echo -e "\033[32m✅ WARP 启动成功"
    echo "IPv4: $(curl -4 --interface wgcf ifconfig.co)"
} || {
    echo -e "\033[31m❌ 启动失败，请检查："
    echo "1. 容器权限：lxc config set 容器名 security.privileged true"
    echo "2. 内核支持：modprobe wireguard"
    exit 1
}