#!/bin/bash

# 定义颜色代码
BLUE='\033[0;34m'     # 蓝色：信息/操作中
GREEN='\033[0;32m'      # 绿色：成功
YELLOW='\033[1;33m'    # 黄色：警告/提示
RED='\033[0;31m'        # 红色：错误
PURPLE='\033[0;35m'     # 紫色：重试操作
NC='\033[0m'            # 重置颜色

# 函数：显示带颜色的消息
function show_msg() {
    case $1 in
        info) echo -e "${BLUE}[信息] $2${NC}" ;;
        success) echo -e "${GREEN}[成功] $2${NC}" ;;
        warning) echo -e "${YELLOW}[警告] $2${NC}" ;;
        error) echo -e "${RED}[错误] $2${NC}" ;;
        retry) echo -e "${PURPLE}[重试] $2${NC}" ;;
    esac
}

# 函数：回滚操作
function rollback() {
    show_msg "warning" "正在执行回滚操作..."
    # 删除可能已创建的文件
    [ -f "/etc/wireguard/wgcf.conf" ] && rm -f "/etc/wireguard/wgcf.conf" && show_msg "info" "已删除配置文件"
    exit 1
}

# 1. 检查WireGuard内核模块
show_msg "info" "正在检查WireGuard内核模块是否存在......"
if lsmod | grep -q wireguard; then
    show_msg "success" "WireGuard内核模块已加载"
else
    show_msg "error" "WireGuard内核模块未加载，请先加载模块"
    exit 1
fi

# 2. 检查并安装依赖工具
show_msg "info" "正在安装相关依赖.工具................"
for tool in wireguard-tools iptables; do
    if command -v $tool &>/dev/null; then
        show_msg "success" "$tool 已安装，跳过"
    else
        show_msg "info" "正在安装 $tool ..."
        if apt-get install -y $tool &>/dev/null || yum install -y $tool &>/dev/null; then
            show_msg "success" "$tool 安装成功"
        else
            show_msg "error" "$tool 安装失败"
            rollback
        fi
    fi
done

# 3. 检查配置文件是否存在
show_msg "info" "正在检测配置文件是否存在..."
CONFIG_FILE="/etc/wireguard/wgcf.conf"
if [ -f "$CONFIG_FILE" ]; then
    show_msg "warning" "配置文件已存在，将使用现有文件"
else
    show_msg "info" "正在创建配置文件..."
    mkdir -p /etc/wireguard
    touch "$CONFIG_FILE"
    if [ $? -eq 0 ]; then
        show_msg "success" "配置空文件已生成"
    else
        show_msg "error" "配置文件创建失败"
        rollback
    fi
fi

# 4. 写入配置文件
show_msg "info" "WireGuard 配置文件写入中...."
cat > "$CONFIG_FILE" <<EOF
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

# 检查文件是否写入成功
if [ $? -eq 0 ]; then
    chmod 600 "$CONFIG_FILE"
    show_msg "success" "配置文件写入成功并已设置权限"
else
    show_msg "error" "配置文件写入失败"
    rollback
fi

# 5. 用户确认是否启动
read -p "$(echo -e ${YELLOW}"是否要立即启动WireGuard? (y/n): "${NC})" choice
case "$choice" in
    y|Y )
        show_msg "info" "正在启动WireGuard..."
        wg-quick up wgcf
        if [ $? -eq 0 ]; then
            show_msg "success" "WireGuard启动成功"
            wg show
        else
            show_msg "error" "WireGuard启动失败"
            rollback
        fi
        ;;
    * )
        show_msg "info" "您选择不启动WireGuard，脚本结束"
        ;;
esac