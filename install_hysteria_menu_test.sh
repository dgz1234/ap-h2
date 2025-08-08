# 以下代码保持原样，无需修改（开始）
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
echo "远程文件版本号: $(get_latest_version)"
read -p "按任意键继续..." -n1 -s

current_version=""
check_hysteria_version() {
    local program_path="/usr/local/bin/hysteria"
    
    # 检查程序是否存在
    if [ ! -f "$program_path" ]; then
        echo "本地文件不存在: $program_path"
        return 1
    fi
    
    # 获取当前版本并存入全局变量
    current_version=$("$program_path" version 2>/dev/null)
    if [ -z "$current_version" ]; then
        warning "获取本地文件版本号失败"
        return 2
    fi
    
    return 0
}
echo "本地文件版本号: $(current_version)"
read -p "按任意键继续..." -n1 -s

# 以上代码保持原样，无需修改（结束）

# 安装 hysteria
install_hysteria() {
    get_latest_version
    check_hysteria_version
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