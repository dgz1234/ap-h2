#!/bin/bash
# ==============================================
# Alpine Linux 最小化 WARP 配置脚本 (64MB内存优化版)
# 功能：
#   1. 仅安装必要依赖 (wireguard-tools)
#   2. 使用预生成配置避免内存峰值
#   3. 所有临时文件存放在内存盘 (/tmp)
# 内存占用：<15MB | 磁盘占用：<1MB
# ==============================================

# 颜色定义
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# 配置参数
CONFIG_DIR="/tmp/wgcf"          # 内存盘存储
CONFIG_FILE="$CONFIG_DIR/wgcf.conf"
LOG_FILE="/dev/null"            # 禁用日志写入

# 预置 Cloudflare WARP 公钥
CF_PUBLIC_KEY="bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="

# ==============================================
# 函数：内存检查（大于20MB才继续）
# ==============================================
check_memory() {
    local available_mem=$(free -m | awk '/Mem:/{print $4}')
    [ "$available_mem" -lt 20 ] && {
        echo -e "${RED}错误：剩余内存不足 (${available_mem}MB < 20MB)${NC}" >&2
        exit 1
    }
}

# ==============================================
# 函数：生成最小化 WireGuard 配置
# ==============================================
generate_config() {
    mkdir -p "$CONFIG_DIR"
    check_memory
    
    cat > "$CONFIG_FILE" <<EOF
[Interface]
PrivateKey = $(wg genkey | tee "$CONFIG_DIR/private.key")
Address = 172.16.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = $CF_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = engage.cloudflareclient.com:2408
PersistentKeepalive = 25
EOF
}

# ==============================================
# 主安装流程
# ==============================================
echo -e "${GREEN}[1/3] 安装wireguard-tools...${NC}"
check_memory
apk add --no-cache wireguard-tools 2>"$LOG_FILE" || {
    echo -e "${RED}安装失败！请检查网络或内存${NC}" >&2
    exit 1
}

echo -e "${GREEN}[2/3] 生成WARP配置...${NC}"
generate_config

echo -e "${GREEN}[3/3] 启动WireGuard...${NC}"
wg-quick up "$CONFIG_FILE" 2>"$LOG_FILE" || {
    echo -e "${RED}启动失败！请检查配置${NC}" >&2
    exit 1
}

# ==============================================
# 验证连接
# ==============================================
echo -e "${YELLOW}测试IPv4连通性...${NC}"
curl --max-time 5 --interface wgcf -4 ifconfig.co 2>"$LOG_FILE" && {
    echo -e "${GREEN}√ WARP 运行成功！${NC}"
} || {
    echo -e "${RED}× 连接测试失败${NC}" >&2
}

# 清理陷阱
trap "wg-quick down '$CONFIG_FILE' 2>/dev/null; rm -rf '$CONFIG_DIR'" EXIT