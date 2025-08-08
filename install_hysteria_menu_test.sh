#!/bin/ash
# 脚本名称：hysteria_installer.sh
# 描述：Alpine Linux Hysteria2 安装工具
# 作者：dgz1234

# ======================== 📦 常量定义 ========================
# 颜色定义
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
PURPLE='\033[1;35m'
NC='\033[0m' # 无颜色

# 显示带颜色的消息函数
info() { echo -e "${BLUE}[信息]${NC} $1"; }
success() { echo -e "${GREEN}[成功]${NC} $1"; }
warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
error() { echo -e "${RED}[错误]${NC} $1"; }
retry() { echo -e "${PURPLE}[重试]${NC} $1"; }

# 获取最新版本号
get_latest_version() {
    temp_file=$(mktemp)
    if ! wget -qO- https://api.github.com/repos/apernet/hysteria/releases/latest > "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi
    # 提取版本号并移除 app/v 或 v 前缀
    latest_version=$(grep '"tag_name":' "$temp_file" | cut -d'"' -f4 | sed -E 's/^(app\/)?v//')
    rm -f "$temp_file"
    if [ -z "$latest_version" ]; then
        return 1
    fi
    echo "$latest_version"  # 现在只输出数字版本号（如 2.6.2）
    return 0
}
echo "最新版本号: $(get_latest_version)"
read -p "按任意键继续..." -n1 -s
# 版本比对函数
compare_versions() {
    local current_ver=$1
    local latest_ver=$2
    
    # 提取纯净版本号 (如从 "v2.6.2" 或 "app/v2.6.2" 中提取 "2.6.2")
    current_clean=$(echo "$current_ver" | head -n 1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
    latest_clean=$(echo "$latest_ver" | sed 's/^app\/v//;s/^v//')
    
    if [ -z "$current_clean" ] || [ -z "$latest_clean" ]; then
        return 2  # 版本获取失败
    fi
    
    if [ "$current_clean" = "$latest_clean" ]; then
        return 0  # 版本匹配
    else
        return 1  # 版本不匹配
    fi
}
echo "测试结果: $(get_latest_version)"
# 安装 hysteria
install_hysteria() {

    latest_version=$(get_latest_version)
    if [ -z "$latest_version" ]; then
        error "无法获取最新版本"
        return 1
    fi
    success "最新版本: $latest_version"

    if [ -f "/usr/local/bin/hysteria" ]; then
        current_version=$(/usr/local/bin/hysteria version 2>/dev/null)
        
        compare_versions "$current_version" "$latest_version"
        case $? in
            0)
                success "当前已安装最新版本 ($latest_version)，跳过下载"
                ;;
            1)
                current_clean=$(echo "$current_version" | head -n 1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
                latest_clean=$(echo "$latest_version" | sed 's/^app\/v//;s/^v//')
                warning "发现旧版本 ($current_clean)，最新版本为 ($latest_clean)"
                read -p "是否更新到最新版本? [y/N] " update_choice
                if [[ "$update_choice" =~ ^[Yy]$ ]]; then
                    rm -f /usr/local/bin/hysteria
                else
                    info "跳过更新"
                    return 0
                fi
                ;;
            2)
                warning "版本比对失败，强制更新"
                rm -f /usr/local/bin/hysteria
                ;;
        esac
    fi
}

# 主菜单
main_menu() {
    while true; do
        show_header
        echo -e "${BLUE}1. 安装 hysteria2\n2. 卸载 hysteria2\n3. 退出脚本${NC}"
        echo "===================================="
        read -p "请输入选项 [1-3]: " choice
        case "$choice" in
            1) install_hysteria ;;
            2) uninstall_hysteria ;;
            3) info "退出脚本"; exit 0 ;;
            *) error "无效选项，请重新输入" ;;
        esac
        read -p "按回车键返回主菜单..."
    done
}

# 脚本入口
main_menu