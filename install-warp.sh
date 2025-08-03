#!/bin/bash

# ==============================================
# Alpine Linux WARP 配置脚本
# 功能：
#   1. 检查/添加edge仓库
#   2. 安装必要依赖
#   3. 管理WARP账户注册
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
MAX_RETRIES=3

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
# 功能函数：带重试的命令执行
# 参数：
#   $1: 命令
#   $2: 成功消息
#   $3: 错误消息
#   $4: 最大重试次数
# ==============================================
function execute_with_retry {
    local cmd="$1"
    local success_msg="$2"
    local error_msg="$3"
    local max_retries=${4:-1}
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        print_msg "$PURPLE" "尝试 $((retry_count+1))/$max_retries: 执行 $cmd"
        
        if eval "$cmd"; then
            print_msg "$GREEN" "√ $success_msg"
            return 0
        fi
        
        ((retry_count++))
        
        if [ $retry_count -lt $max_retries ]; then
            sleep 1
        fi
    done
    
    print_msg "$RED" "× $error_msg (尝试 $max_retries 次后失败)"
    return 1
}

# ==============================================
# 第一部分：检查并添加edge仓库
# ==============================================
print_msg "$BLUE" "[1/4] 检查Alpine edge仓库..."

if grep -q "$EDGE_MAIN" "$REPO_FILE" && grep -q "$EDGE_TESTING" "$REPO_FILE"; then
    print_msg "$GREEN" "√ 源文件已包含edge仓库"
else
    print_msg "$YELLOW" "! 检测到缺少edge仓库"
    
    # 添加仓库
    echo -e "\n# 添加Alpine Edge仓库\n$EDGE_MAIN\n$EDGE_TESTING\n" >> "$REPO_FILE"
    
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
print_msg "$BLUE" "\n[2/4] 安装必要依赖工具..."

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
print_msg "$BLUE" "\n[3/4] 检查WARP账户配置..."

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
print_msg "$BLUE" "\n[4/4] 注册Cloudflare WARP账户..."

register_cmd="wgcf register --accept-tos --config $ACCOUNT_FILE"
execute_with_retry "$register_cmd" "WARP账户注册成功" "WARP账户注册失败" $MAX_RETRIES || {
    if confirm "注册失败，是否退出脚本？"; then
        exit 1
    fi
}

print_msg "$GREEN" "\n√ 所有操作已完成！"