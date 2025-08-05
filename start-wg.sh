#!/bin/bash

# 定义颜色代码
BLUE='\033[0;34m'     # 信息/操作中
GREEN='\033[0;32m'    # 成功
YELLOW='\033[1;33m'   # 警告/提示
RED='\033[0;31m'      # 错误
PURPLE='\033[0;35m'   # 重试操作
NC='\033[0m'          # 重置颜色

# 检查root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[错误] 请使用root用户执行本脚本${NC}"
    exit 1
fi

# 显示彩色消息函数
show_msg() {
    case $1 in
        info) echo -e "${BLUE}[信息] $2${NC}" ;;
        success) echo -e "${GREEN}[成功] $2${NC}" ;;
        warning) echo -e "${YELLOW}[警告] $2${NC}" ;;
        error) echo -e "${RED}[错误] $2${NC}" ;;
        retry) echo -e "${PURPLE}[重试] $2${NC}" ;;
    esac
}

# Alpine专用回滚函数
rollback() {
    show_msg warning "正在执行回滚操作..."
    # 删除配置文件
    [ -f "/etc/wireguard/wgcf.conf" ] && {
        rm -f "/etc/wireguard/wgcf.conf"
        show_msg info "已删除配置文件"
    }
    # 卸载新安装的包
    local installed=()
    for pkg in wireguard-tools iptables; do
        if apk info -e $pkg >/dev/null 2>&1; then
            installed+=("$pkg")
        fi
    done
    [ ${#installed[@]} -gt 0 ] && {
        apk del --no-cache "${installed[@]}" >/dev/null 2>&1
        show_msg info "已卸载包: ${installed[*]}"
    }
    exit 1
}

# 1. 检查WireGuard内核模块
show_msg info "正在检查WireGuard内核模块..."
if lsmod | grep -q wireguard; then
    show_msg success "WireGuard内核模块已加载"
else
    show_msg warning "尝试加载WireGuard内核模块..."
    modprobe wireguard 2>/dev/null || {
        show_msg error "内核模块加载失败，请先执行："
        echo -e "  apk add --no-cache wireguard-tools linux-lts-wireguard"
        echo -e "  modprobe wireguard"
        exit 1
    }
    show_msg success "内核模块加载成功"
fi

# 2. 检查Alpine依赖包
show_msg info "正在检查必需软件包..."
for pkg in wireguard-tools iptables; do
    if apk info -e $pkg >/dev/null 2>&1; then
        show_msg success "$pkg 已安装"
    else
        show_msg info "正在安装 $pkg..."
        if ! apk add --no-cache $pkg >/dev/null 2>&1; then
            show_msg error "$pkg 安装失败"
            rollback
        fi
        show_msg success "$pkg 安装完成"
    fi
done

# 3. 检查配置文件目录
CONFIG_FILE="/etc/wireguard/wgcf.conf"
show_msg info "正在检查配置文件..."
if [ -f "$CONFIG_FILE" ]; then
    show_msg warning "配置文件已存在，将追加配置"
else
    mkdir -p /etc/wireguard
    chmod 700 /etc/wireguard
    show_msg success "配置目录已创建"
fi

# 4. 写入配置文件
show_msg info "正在生成WireGuard配置..."
cat > "$CONFIG_FILE" <<-EOF
[Interface]
PrivateKey = $(wg genkey)
Address = 172.16.0.2/32, 2606:4700:110:8da4:c505:b2c:f503:c10b/128
MTU = 1280
# DNS = 1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0
Endpoint = engage.cloudflareclient.com:2408
EOF

# 设置配置文件权限
chmod 600 "$CONFIG_FILE"
show_msg success "配置文件已生成并设置权限"

# 5. 用户确认启动
read -p "$(echo -e ${YELLOW}"是否立即启动WireGuard? [y/N] "${NC})" choice
case "$choice" in
    y|Y)
        show_msg info "正在启动WireGuard..."
        if wg-quick up wgcf; then
            show_msg success "WireGuard启动成功"
            wg show
        else
            show_msg error "WireGuard启动失败"
            rollback
        fi
        ;;
    *)
        show_msg info "您可以选择稍后手动启动："
        echo -e "  wg-quick up wgcf"
        echo -e "  wg-quick down wgcf"
        ;;
esac