#!/bin/bash

# ==============================================
# Alpine Linux WARP 配置脚本
# 功能：
#   1. 检查/添加edge仓库
#   2. 安装必要依赖
#   3. 管理WARP账户注册
#   4. 生成WireGuard配置
# 设计特点：
#   - 完整的彩色输出系统
#   - 完善的错误处理
#   - 用户交互选项
# ==============================================

# 颜色定义
RED='\033[0;31m'      # 错误/警告
GREEN='\033[0;32m'    # 成功
YELLOW='\033[1;33m'   # 提示/警告
BLUE='\033[0;34m'     # 信息
PURPLE='\033[0;35m'   # 操作中
NC='\033[0m'          # 重置颜色

# 常量定义
REPO_FILE="/etc/apk/repositories"
EDGE_MAIN="http://dl-cdn.alpinelinux.org/alpine/edge/main"
EDGE_TESTING="http://dl-cdn.alpinelinux.org/alpine/edge/testing"
DEPENDENCIES=("wgcf" "wireguard-tools" "openresolv" "iptables" "ip6tables")
ACCOUNT_FILE="/etc/wireguard/accounts/wgcf-account.toml"
CONFIG_FILE="/etc/wireguard/wgcf.conf"
MAX_RETRIES=3
DELAY_SECONDS=5

# ==============================================
# 功能函数：彩色打印
# 参数：
#   $1: 颜色代码
#   $2: 消息内容
# ==============================================
function print_msg {
    echo -e "${1}${2}${NC}"
}

# ==============================================
# 功能函数：用户确认
# 参数：
#   $1: 提示信息
# 返回：
#   0: 用户确认
#   1: 用户取消
# ==============================================
function confirm {
    read -p "$(echo -e "${YELLOW}${1} [y/N]: ${NC}")" choice
    case "$choice" in
        y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

# ==============================================
# 第一部分：检查并添加edge仓库
# ==============================================
print_msg "$BLUE" "[1/5] 检查Alpine edge仓库..."

if grep -q "$EDGE_MAIN" "$REPO_FILE" && grep -q "$EDGE_TESTING" "$REPO_FILE"; then
    print_msg "$GREEN" "√ 源文件已包含edge仓库"
else
    print_msg "$YELLOW" "! 检测到缺少edge仓库"
    
    # 添加仓库
    echo "$EDGE_MAIN" >> "$REPO_FILE"
    echo "$EDGE_TESTING" >> "$REPO_FILE"
    
    if grep -q "$EDGE_MAIN" "$REPO_FILE"; then
        print_msg "$GREEN" "√ 源文件已成功添加edge仓库"
    else
        print_msg "$RED" "× 添加edge仓库失败"
        exit 1
    fi
    
    # 更新仓库
    if apk update; then
        print_msg "$GREEN" "√ 仓库更新成功"
    else
        print_msg "$RED" "× 仓库更新失败"
        exit 1
    fi
fi

# ==============================================
# 第二部分：安装依赖工具
# ==============================================
print_msg "$BLUE" "\n[2/5] 安装必要依赖工具..."

for pkg in "${DEPENDENCIES[@]}"; do
    if apk info -e "$pkg" >/dev/null 2>&1; then
        print_msg "$GREEN" "√ $pkg 已安装"
    else
        print_msg "$YELLOW" "! 正在安装 $pkg..."
        if apk add --no-cache "$pkg"; then
            print_msg "$GREEN" "√ $pkg 安装成功"
        else
            print_msg "$RED" "× $pkg 安装失败"
            exit 1
        fi
    fi
done

# ==============================================
# 第三部分：检查WARP账户
# ==============================================
print_msg "$BLUE" "\n[3/5] 检查WARP账户配置..."

if [ -f "$ACCOUNT_FILE" ]; then
    print_msg "$YELLOW" "! 检测到已存在的账户文件: $ACCOUNT_FILE"
    if confirm "是否保留现有账户配置？"; then
        print_msg "$GREEN" "√ 保留现有账户配置"
        exit 0
    else
        print_msg "$YELLOW" "! 正在删除现有账户文件..."
        rm -f "$ACCOUNT_FILE"
    fi
fi

# 创建账户目录
mkdir -p "$(dirname "$ACCOUNT_FILE")"

# ==============================================
# 第四部分：注册WARP账户
# ==============================================
print_msg "$BLUE" "\n[4/5] 注册Cloudflare WARP账户..."

register_cmd="wgcf register --accept-tos --config $ACCOUNT_FILE"
retry_count=0

while [ $retry_count -lt $MAX_RETRIES ]; do
    print_msg "$PURPLE" "尝试 $((retry_count+1))/$MAX_RETRIES: 注册WARP账户..."
    
    # 在每次尝试前删除可能已存在的账户文件
    if [ -f "$ACCOUNT_FILE" ]; then
        rm -f "$ACCOUNT_FILE"
        print_msg "$YELLOW" "! 已删除存在的账户文件: $ACCOUNT_FILE"
    fi
    
    if $register_cmd; then
        print_msg "$GREEN" "√ WARP账户注册成功"
        break
    else
        ((retry_count++))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            print_msg "$YELLOW" "! ${DELAY_SECONDS}秒后继续尝试..."
            sleep $DELAY_SECONDS
        else
            print_msg "$RED" "× WARP账户注册失败 (尝试 $MAX_RETRIES 次后失败)"
            
            # 删除账户文件
            if [ -f "$ACCOUNT_FILE" ]; then
                rm -f "$ACCOUNT_FILE"
                print_msg "$YELLOW" "! 已删除账户文件: $ACCOUNT_FILE"
            fi
            
            print_msg "$RED" "× 脚本执行失败，退出..."
            exit 1
        fi
    fi
done

# ==============================================
# 第五部分：生成 WireGuard 配置文件
# ==============================================
print_msg "$BLUE" "\n[5/5] WireGuard 配置文件生成..."

# 生成配置文件
generate_cmd="wgcf generate --config $ACCOUNT_FILE -p $CONFIG_FILE"
if $generate_cmd; then
    print_msg "$GREEN" "√ WireGuard 配置文件生成成功"
else
    print_msg "$RED" "× WireGuard 配置文件生成失败"
    exit 1
fi

# 修改配置文件
print_msg "$YELLOW" "! 正在优化配置文件..."
sed -i 's/^DNS =/# DNS =/' "$CONFIG_FILE" && \
sed -i 's/^AllowedIPs = .*/AllowedIPs = 0.0.0.0\/0/' "$CONFIG_FILE" && \
print_msg "$GREEN" "√ 配置文件优化完成" || \
print_msg "$RED" "× 配置文件优化失败"

# 询问是否启动WireGuard
if confirm "是否立即启动WireGuard？"; then
    print_msg "$BLUE" "启动WireGuard..."
    wg-quick up wgcf 2>/dev/null
    if [ $? -eq 0 ]; then
        print_msg "$GREEN" "√ WireGuard 启动成功！"
        print_msg "$GREEN" "当前DNS配置："
        cat /etc/resolv.conf
    else
        print_msg "$RED" "× WireGuard 启动失败！"
    fi
fi

print_msg "$GREEN" "\n√ 所有操作已完成！配置文件保存在: $CONFIG_FILE"