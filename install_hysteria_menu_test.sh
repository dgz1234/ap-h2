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

# 获取远程版本（完美处理 app/v 前缀）
get_remote_version() {
    curl -fsSL https://api.github.com/repos/apernet/hysteria/releases/latest |
    grep '"tag_name":' | 
    cut -d'"' -f4 |
    sed 's|^app/v||;s|^v||'  # 同时处理 app/v 和 v 前缀
}

# 获取本地版本（超强兼容）
get_local_version() {
    if [ -x "/usr/local/bin/hysteria" ]; then
        /usr/local/bin/hysteria version 2>/dev/null |
        grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' |
        head -1 || echo "get_failed"
    else
        echo "not_installed"
    fi
}

# 以上代码保持原样，无需修改（结束）

# ======================== ⬇️ 分层下载实现 ========================
_download_and_install() {
    # 函数: _download_and_install
    # 用途: 核心安装逻辑 (私有函数)
    # 参数:
    #   $1: 下载URL
    #   $2: 临时文件路径
    # 返回:
    #   0: 成功 | 1: 下载失败 | 2: 权限错误
    local url=$1
    local tmp_file=$2

    if ! curl -#fSL "$url" -o "$tmp_file"; then
        error "下载失败"
        return 1
    fi

    chmod +x "$tmp_file" || return 2
    mv "$tmp_file" /usr/local/bin/hysteria || return 3
    return 0
}

download_hysteria() {
    # 函数: download_hysteria
    # 用途: 带架构检测的下载器
    # 参数:
    #   $1: 版本号 (如 2.6.2)
    local version=$1
    local arch
    
    case $(uname -m) in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) error "不支持的架构"; return 1 ;;
    esac

    local tmp_file=$(mktemp)
    trap "rm -f '$tmp_file'" EXIT

    info "正在下载 v$version [$arch]..."
    if _download_and_install \
       "https://github.com/apernet/hysteria/releases/download/app/v$version/hysteria-linux-$arch" \
       "$tmp_file"; then
        success "安装成功"
    else
        error "安装失败 (错误码: $?)"
        return 1
    fi
}

# ======================== 🔄 版本控制 ========================
check_and_update_version() {
    local remote=$(get_remote_version) || return 1
    local local=$(get_local_version)

    case "$local" in
        "$remote") success "已是最新版 (v$local)"; return 0 ;;
        "not_installed") info "开始安装 v$remote"; download_hysteria "$remote" ;;
        "get_failed") warning "修复安装"; download_hysteria "$remote" ;;
        *) 
            warning "发现更新 (v$local → v$remote)"
            read -p "是否更新? [Y/n] " choice
            case "${choice:-Y}" in
                [Yy]*) download_hysteria "$remote" ;;
                *) info "已取消" ;;
            esac
            ;;
    esac
}

# ======================== 🖥️ 用户界面 ========================
show_menu() {
    clear
    echo -e "${GREEN}=== Hysteria2 管理菜单 ==="
    echo "1. 检查更新"
    echo "2. 强制重新安装"
    echo "3. 退出"
    echo -e "=========================${NC}"
}

main() {
    while true; do
        show_menu
        echo "最新版本: $(get_remote_version)"
        echo "本地版本: $(get_local_version)"
        
        read -p "请选择: " choice
        case "$choice" in
            1) check_and_update_version ;;
            2) download_hysteria "$(get_remote_version)" ;;
            3) exit 0 ;;
            *) error "无效输入" ;;
        esac
        
        read -n 1 -s -p "按任意键继续..."
    done
}

# ======================== 🚀 脚本入口 ========================
main