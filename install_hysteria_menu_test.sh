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

# ======================== 🔄 版本检查与更新 ========================
download_hysteria() {
    # 获取版本信息
    local remote_version=$(get_remote_version)
    local local_version=$(get_local_version)

    # 检查版本获取状态
    if [ -z "$remote_version" ]; then
        error "无法获取最新版本信息，请检查网络连接"
        return 1
    fi

    # 情况1：未安装
    if [ "$local_version" = "not_installed" ]; then
        info "正在为您安装 Hysteria v$remote_version..."
        _download_hysteria "$remote_version"
        return $?
    fi

    # 情况2：获取本地版本失败
    if [ "$local_version" = "get_failed" ]; then
        warning "无法读取当前版本，将尝试修复安装..."
        _download_hysteria "$remote_version"
        return $?
    fi

    # 情况3：版本比对
    if [ "$local_version" = "$remote_version" ]; then
        success "您的 Hysteria 已经是最新版 (v$local_version)"
        return 0
    else
        warning "发现新版本可用 (当前: v$local_version → 最新: v$remote_version)"
        echo -e "${YELLOW}┌───────────────────────────────────────┐"
        echo -e "│ 是否要更新到最新版本？              │"
        echo -e "│ [${GREEN}Y${NC}]es 确认更新   [${RED}N${NC}]o 保持当前版本 │"
        echo -e "└───────────────────────────────────────┘${NC}"
        read -p "请输入选择 [Y/N]: " choice
        
        case "$choice" in
            [yY]|[yY][eE][sS])
                info "正在准备更新..."
                _download_hysteria "$remote_version"
                ;;
            *)
                info "已保留当前版本 v$local_version"
                ;;
        esac
    fi
}
# ======================== ⬇️ 内部下载实现 ========================
_download_hysteria() {
    # 函数: _download_and_install
    # 用途: 核心安装逻辑 (私有函数)
    # 参数:
    #   $1: 下载URL
    #   $2: 临时文件路径
    # 返回:
    #   0: 成功 | 1: 下载失败 | 2: 权限错误
    # 示例:
    #   _download_and_install "https://..." "/tmp/file"
    local version=$1
    info "正在获取 Hysteria v$version 安装包..."
    
    # 创建临时目录（自动清理）
    local tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT
    
    # 自动检测系统架构
    case $(uname -m) in
        x86_64) local arch="amd64" ;;
        aarch64) local arch="arm64" ;;
        *) error "抱歉，您的设备架构暂不支持"; return 1 ;;
    esac

    # 进度显示下载
    if ! curl -#fSL "https://github.com/apernet/hysteria/releases/download/app/v$version/hysteria-linux-$arch" \
         -o "$tmp_dir/hysteria"; then
        error "下载失败，请重试或检查网络"
        return 2
    fi
    
    # 执行安装
    chmod +x "$tmp_dir/hysteria"
    if ! mv "$tmp_dir/hysteria" /usr/local/bin/; then
        error "安装失败，请尝试使用 sudo 运行"
        return 3
    fi
    
    success "恭喜！Hysteria 已成功升级到 v$version"
    return 0
}
# 执行并打印结果
echo "最新版本: $(get_remote_version)"
echo "本地版本: $(get_local_version)"
read -p "按任意键继续..." -n1 -s


# 主菜单
main_menu() {
    download_hysteria
}

# 脚本入口
main_menu