#!/bin/ash
# 脚本名称：hysteria_installer.sh
# 描述：Alpine Linux Hysteria2 安装工具
# 适用机器类型：Alpine Linux-LXC容器-IPv6-only-无NAT64网关-wireguard内核支持-客户端root-64M内存-90M磁盘
# 作者：dgz1234
# ======================== 📦 常量定义 ========================
SCRIPT_NAME="hysteria_installer.sh"
SCRIPT_VERSION="1.1.0"
DOC_URL="https://v2.hysteria.network/zh/docs/getting-started/Installation/"
ACTION=""
# ==================== 颜色定义 ====================
BLUE='\033[1;34m'     # 亮蓝 - 信息
GREEN='\033[1;32m'    # 亮绿 - 成功
YELLOW='\033[1;33m'   # 亮黄 - 警告
RED='\033[1;31m'      # 亮红 - 错误
PURPLE='\033[1;35m'   # 亮紫 - 重试/特殊提示
NC='\033[0m'          # 颜色重置

# ==================== 输出函数 ====================
info()    { echo -e "${BLUE}[信息] $1${NC}"; }                  # 常规信息
success() { echo -e "${GREEN}[成功] $1${NC}"; }                 # 成功操作
warning() { echo -e "${YELLOW}[警告] $1${NC}"; }                # 非致命警告
error()   { echo -e "${RED}[错误] $1${NC}" >&2; }               # 致命错误（输出到stderr）
retry()   { echo -e "${PURPLE}[重试] $1${NC}"; }                # 重试提示
confirm() { echo -e "${BLUE}[确认] $1${NC} [y/N]: "; }          # 确认提示（新增）

# ==================== 帮助文档函数 ====================
show_help() {
    echo -e "${GREEN}Hysteria2 安装工具 v${SCRIPT_VERSION}${NC}"
    echo -e "适用环境: Alpine Linux LXC (IPv6-only)"
    echo
    echo -e "${BLUE}用法:${NC}"
    echo -e "  install_hysteria.sh [选项]"
    echo
    echo -e "${YELLOW}选项:${NC}"
    echo -e "  ${GREEN}-h, --help${NC}     显示此帮助信息"
    echo -e "  ${GREEN}-v, --version${NC}  显示版本信息"
    echo -e "  ${GREEN}install${NC}        安装Hysteria2 (默认选项)"
    echo -e "  ${GREEN}uninstall${NC}      卸载Hysteria2"
    echo
    echo -e "${PURPLE}示例:${NC}"
    echo -e "  install_hysteria.sh install"
    echo -e "  install_hysteria.sh --help"
    echo
    echo -e "${RED}注意:${NC}"
    echo -e "  1. 需要root权限执行"
    echo -e "  2. 推荐使用以下方式安装："
    echo -e "     curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/main/install_hysteria.sh | bash"
    echo -e "  3. 完整文档: ${DOC_URL}"
    exit 0
}

# ==================== 参数解析 ====================
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)      show_help ;;
            -v|--version)   show_version ;;
            install)        ACTION=install ;;
            uninstall)      ACTION=uninstall ;;
            *)              error "无效参数: $1"; exit 1 ;;
        esac
        shift
    done
}
show_version() {
    echo "hysteria-installer v${SCRIPT_VERSION}"
    exit 0
}

# ==================== 显示大标题 ==================== 
show_header() {
    clear
    echo -e "${BLUE}"
    echo "  _   _ _   _ _____ _____ ____  ___ ____  "
    echo " | | | | | | |_   _| ____|  _ \|_ _|  _ \ "
    echo " | |_| | | | | | | |  _| | |_) || || |_) |"
    echo " |  _  | |_| | | | | |___|  _ < | ||  __/ "
    echo " |_| |_|\___/  |_| |_____|_| \_\___|_|    "
    echo -e "${NC}"
    echo -e "${YELLOW}Alpine Linux Hysteria2 安装脚本${NC}"
    echo "                                           "
}
# ======================== 🔧 工具函数 ========================
# 1.检查IPv4支持
check_ipv4() {
    info "网络环境检测中......"
    if ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
        success "网络环境正常 (IPv4支持)"
        return 0
    else
        error "您的网络需要IPv4支持"
        warning "如果您使用的是LXC容器-IPv6-only-无NAT64网关，建议先安装WARP"
        echo
        while true; do
            read -p "$(echo -e "${YELLOW}是否继续安装？(y=继续/n=返回菜单): ${NC}")" choice
            case "$choice" in
                [yY]*) 
                    warning "您选择了继续安装，网络功能可能受限"
                    return 0  # 继续执行
                    ;;
                [nN]*) 
                    info "返回主菜单..."
                    return 1  # 返回菜单
                    ;;
                *) 
                    error "无效输入，请输入 y 或 n"
                    ;;
            esac
        done
    fi
}

# 2.版本控制
# ======================== 🔄 版本检查与更新 ========================
# 2.1.获取远程版本（完美处理 app/v 前缀）
get_remote_version() {
    local version
    local max_retries=2
    local retry_delay=1
    
    # 尝试API方式 (带重试机制)
    for ((i=1; i<=$max_retries; i++)); do
        version=$(_fetch_via_api)
        if [ $? -eq 0 ] && [ -n "$version" ]; then
            echo "$version"
            return 0
        else
            warning "[尝试 $i/$max_retries] API获取失败，等待 ${retry_delay}秒后重试..."
            sleep $retry_delay
        fi
    done
    
    # 降级到非API方式
    warning "正在使用备用方式获取版本..."
    version=$(_fetch_via_web)
    
    if [ -n "$version" ]; then
        echo "$version"
    else
        error "错误：所有版本获取方式均失败"
        return 1
    fi
}

# 2.1.1.API方式获取远程版本   
_fetch_via_api() {
    curl --connect-timeout 5 -fsSL \
        https://api.github.com/repos/apernet/hysteria/releases/latest 2>/dev/null |
        grep -o '"tag_name": *"[^"]*"' |
        cut -d'"' -f4 |
        sed 's|^app/v||;s|^v||'
}

# 2.1.2.非API方式获取远程版本
_fetch_via_web() {
    curl -fsSL -I \
        https://github.com/apernet/hysteria/releases/latest 2>/dev/null |
        tr -d '\r' |
        awk -F'/' '/location:/{print $NF}' |
        sed 's|^app/v||;s|^v||'
}

# 2.2.获取本地版本（超强兼容）
get_local_version() {
    if [ -x "/usr/local/bin/hysteria" ]; then
        /usr/local/bin/hysteria version 2>/dev/null |
        grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' |
        head -1 || echo "get_failed"
    else
        echo "not_installed"
    fi
}

# ======================== 🔄 版本控制 ========================
check_and_update_version() {
    # 获取远程版本（带严格错误检查）
    local remote
    remote=$(get_remote_version 2>/dev/null)
    local ret=$?
    
    if [ $ret -ne 0 ] || [ -z "$remote" ]; then
        error "无法获取远程版本号 (错误码: $ret)"
        error "请检查网络连接或GitHub访问状态"
        return 1
    fi

    # 获取本地版本
    local local
    local=$(get_local_version)
    
    # 版本比较逻辑
    case "$local" in
        "$remote")
            success "已是最新版 (v$local)"
            exit 0
            ;;
        "not_installed")
            info "开始全新安装 v$remote"
            if ! download_hysteria "$remote"; then
                error "安装失败"
                exit 1
            fi
            ;;
        "get_failed")
            warning "尝试修复安装 (当前版本获取失败)"
            if ! download_hysteria "$remote"; then
                error "修复安装失败"
                exit 1
            fi
            ;;
        *)
            if version_gt "$remote" "$local"; then
                warning "发现更新 (v$local → v$remote)"
                read -p "是否更新? [Y/n] " choice
                case "${choice:-Y}" in
                    [Yy]*) 
                        if ! download_hysteria "$remote"; then
                            error "更新失败"
                            exit 1
                        fi
                        ;;
                    *)
                        info "已取消更新"
                        exit 0
                        ;;
                esac
            else
                warning "本地版本 (v$local) 比远程版本 (v$remote) 更新"
                warning "可能是开发版或自定义构建，跳过更新"
                exit 0
            fi
            ;;
    esac
}

# 版本比较函数
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# ======================== ⬇️ 分层下载实现 ========================

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
        success "下载成功"
    else
        error "下载失败 (错误码: $?)"
        return 1
    fi
}

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

# 3.安装依赖
install_dependencies() {
    info "正在检测相关依赖..."
    if ! command -v openssl >/dev/null 2>&1; then
        warning "openssl未安装，正在安装..."
        apk add --no-cache openssl || {
            error "openssl安装失败"
            return 1
        }
        success "openssl已安装"
    else
        success "openssl已正常安装"
    fi
    return 0
}


# 4.生成自签名证书
generate_self_signed_cert() {
    info "正在生成自签名证书..."
    openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
    openssl req -new -x509 -days 36500 -key /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=www.bing.com"
    chown hysteria:hysteria /etc/hysteria/server.key /etc/hysteria/server.crt
    chmod 600 /etc/hysteria/server.key
    success "自签名证书已生成"
}

# 5.生成配置文件
generate_config_file() {
    local port=$1
    local password=$2
    
    # 获取上行带宽设置
    echo -e "${YELLOW}┌────────────────────────────────────────────────────────────┐"
    echo -e "│ ${BLUE}⚠ 带宽参数直接影响Hysteria2的速率和稳定性，请真实输入！${YELLOW}       │"
    echo -e "├────────────────────────────────────────────────────────────┤"
    echo -e "│ ${NC}中国移动300兆家庭带宽参考值：上行345mbps，下行46mbps${YELLOW}            │"
    echo -e "└────────────────────────────────────────────────────────────┘${NC}"

    while true; do
        echo -e "${YELLOW}┌────────────────────────────────────────────────────────────┐"
        echo -ne "│ ${BLUE}↳ 请输入上行带宽 ${NC}(${GREEN}默认: 345 mbps${NC}): ${YELLOW}"
        read -r up_bandwidth
        up_bandwidth=${up_bandwidth:-"345 mbps"}
        
        echo -ne "│ ${BLUE}↳ 请输入下行带宽 ${NC}(${GREEN}默认: 46 mbps${NC}): ${YELLOW}"
        read -r down_bandwidth
        down_bandwidth=${down_bandwidth:-"46 mbps"}
        echo -e "└────────────────────────────────────────────────────────────┘${NC}"

        echo -e "${YELLOW}┌────────────────────────────────────────────────────────────┐"
        echo -e "│ ${BLUE}✔ 当前设置: 上行 ${GREEN}${up_bandwidth}${BLUE} 下行 ${GREEN}${down_bandwidth}${YELLOW}                    │"
        echo -e "├────────────────────────────────────────────────────────────┤"
        echo -e "│ ${BLUE}是否确认配置？${NC}                                            │"
        echo -e "│ ${GREEN}[Y]${NC}es 确认配置   ${RED}[N]${NC}o 重新输入   ${PURPLE}[C]${NC}ancel 中止安装 │"
        echo -e "└────────────────────────────────────────────────────────────┘${NC}"
        
        while true; do
            read -p "$(echo -e "${BLUE}↳ 请选择 [Y/N/C]: ${NC}")" confirm
            case $confirm in
                [yY]*) 
                    info "正在生成配置文件..."
                    cat > /etc/hysteria/config.yaml <<EOF
listen: :${port}
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
auth:
  type: password
  password: ${password}
bandwidth:
  up: ${up_bandwidth}
  down: ${down_bandwidth}
masquerade:
  type: proxy
  proxy:
    url: https://bing.com/
    rewriteHost: true
socks5:
  listen: "[::]:1080"
EOF
                    chown hysteria:hysteria /etc/hysteria/config.yaml
                    success "配置文件已生成"
                    return 0
                    ;;
                [nN]*) 
                    retry "正在重新输入带宽参数..."
                    break
                    ;;
                [cC]*) 
                    error "用户已取消安装"
                    exit 1
                    ;;
                *) 
                    echo -e "${RED}无效输入，请重新选择${NC}"
                    ;;
            esac
        done
    done
}
# 6.配置系统服务
configure_system_service() {
    info "正在配置系统服务..."
    cat > /etc/init.d/hysteria <<EOF
#!/sbin/openrc-run
name="hysteria"
command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"
command_user="hysteria"
pidfile="/var/run/\${name}.pid"
command_background="yes"

depend() {
    need net
    after firewall
}
EOF
    chmod +x /etc/init.d/hysteria
    rc-update add hysteria >/dev/null 2>&1
    /etc/init.d/hysteria start >/dev/null || {
        error "服务启动失败"
        return 1
    }
    success "系统服务已配置"
}

# 7.安装 hysteria
install_hysteria() {
    # 1.检查IPv4支持
    check_ipv4 || return 1
    # 2.版本控制
    check_and_update_version || return 1
    # 3.安装依赖
    install_dependencies || return 1

    read -p "请输入监听端口 (默认: 36711): " port
    port=${port:-36711}
    read -p "请输入密码 (留空将自动生成): " password
    if [ -z "$password" ]; then
        password=$(tr -dc 'A-Za-z0-9,_-' < /dev/urandom | head -c 24)
        info "已生成随机密码: ${password}"
    fi

    if ! id "hysteria" >/dev/null 2>&1; then
        info "正在创建专用用户 hysteria..."
        adduser -D -H -s /sbin/nologin hysteria || {
            error "创建用户失败"
            return 1
        }
        success "专用用户 hysteria 创建成功"
    else
        info "专用用户 hysteria 已存在"
    fi
    mkdir -p /etc/hysteria
    # 生成证书
    if [ ! -f "/etc/hysteria/server.key" ] || [ ! -f "/etc/hysteria/server.crt" ]; then
        generate_self_signed_cert
    else
        info "检测到现有TLS证书，跳过生成"
    fi

    # 生成配置文件
    if [ ! -f "/etc/hysteria/config.yaml" ]; then
        generate_config_file "$port" "$password"
    else
        info "检测到现有配置文件，跳过生成"
    fi

    # 配置系统服务
    configure_system_service

    show_installation_result "$port" "$password"
}

# 8.显示安装结果
show_installation_result() {
    local port=$1
    local password=$2
    # 初始化变量
    ipv4="未检测到IPv4地址"
    ipv6="未检测到IPv6地址"
    
    # 方法1：使用Cloudflare检测服务（兼容Alpine LXC）
    cloudflare_detect() {
        # 使用wget替代curl（Alpine默认不带curl）
        wget -qO- --timeout=3 --bind-address=$(ip route show default | awk '/default/ {print $9}') \
            https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | \
            grep -E '^ip=' | cut -d= -f2
    }
    
    # 优先尝试Cloudflare检测
    if cloudflare_ip=$(cloudflare_detect); then
        # 判断IP类型（兼容BusyBox）
        case "$cloudflare_ip" in
            *.*.*.*)
                ipv4="$cloudflare_ip"
                echo "Cloudflare检测到IPv4: $ipv4"
                ;;
            *:*)
                ipv6="$cloudflare_ip"
                echo "Cloudflare检测到IPv6: $ipv6"
                ;;
            *)
                echo "Cloudflare返回无效IP格式"
                ;;
        esac
    else
        # 方法2：Cloudflare检测失败时使用备用API
        echo "Cloudflare检测失败，使用备用API"
        ipv4=$(wget -4 -qO- --timeout=3 https://api.ipify.org 2>/dev/null || echo "未检测到IPv4地址")
        ipv6=$(wget -6 -qO- --timeout=3 https://api6.ipify.org 2>/dev/null || echo "未检测到IPv6地址")
    fi
    
    # 最终输出
    echo "----------------------"
    echo "最终检测结果："
    echo "IPv4: $ipv4"
    echo "IPv6: $ipv6"
    echo -e "${GREEN}\nHysteria 安装完成！${NC}"
    echo "===================================="
    echo -e "${BLUE}以下是节点信息:${NC}"
    echo "hysteria2://${password}@${ipv4}:${port}?sni=www.bing.com&alpn=h3&insecure=1#alpine-hysteria"
    if [ -n "$ipv6" ] && [ "$ipv6" != "你的IPv6地址" ]; then
        echo "hysteria2://${password}@[${ipv6}]:${port}?sni=www.bing.com&alpn=h3&insecure=1#alpine-hysteria-ipv6"
    fi
    echo "===================================="
    echo -e "${RED}重要提示:${NC}"
    echo "如果你使用ipv6节点信息，请确认客户端支持IPv6连接"
    echo "===================================="
    echo -e "${YELLOW}服务管理命令:${NC}"
    echo "启动: service hysteria start"
    echo "停止: service hysteria stop"
    echo "重启: service hysteria restart"
    echo "状态: service hysteria status"
}

# 9.卸载 hysteria
uninstall_hysteria() {
    # 非交互模式判断
    if [ "$1" != "noninteractive" ]; then
        while true; do
            read -p "$(confirm "确定要卸载Hysteria吗？")" choice
            case "$choice" in
                [yY]*) 
                    break  # 用户确认卸载
                    ;;
                [nN]*) 
                    info "卸载已取消"
                    exit 0
                    ;;
                *) 
                    echo -e "${RED}无效输入，请输入 Y/y 或 N/n${NC}"
                    ;;
            esac
        done
    fi

    info "正在卸载 Hysteria..."
    
    # 服务停止和移除（带错误处理）
    if [ -f /etc/init.d/hysteria ]; then
        /etc/init.d/hysteria stop >/dev/null 2>&1
        rc-update del hysteria >/dev/null 2>&1
        rm -f /etc/init.d/hysteria && success "服务移除" || error "服务移除失败"
    fi

    # 可执行文件删除
    [ -f /usr/local/bin/hysteria ] && \
        rm -f /usr/local/bin/hysteria && success "可执行文件已删除" || \
        warning "未找到可执行文件"

    # 配置目录删除
    if [ -d /etc/hysteria ]; then
        rm -rf /etc/hysteria && success "配置和证书已删除" || \
        error "配置删除失败 (权限问题?)"
    else
        warning "未找到配置目录"
    fi

    # 用户删除
    if id hysteria >/dev/null 2>&1; then
        deluser hysteria >/dev/null 2>&1 && success "用户已删除" || \
        error "用户删除失败 (权限问题?)"
    fi

    success "Hysteria 已卸载"
}

# ======================== 🖥️ 用户界面 ========================
main_menu() {
    # 如果已有参数则跳过菜单
    [ -n "$1" ] && return
    while true; do
        show_header
        echo
        echo -e "${BLUE}================ 🔄 版本控制 ================${NC}"
        echo
        echo "最新版本: $(check_and_update_version)"
        echo "本地版本: $(get_local_version)"
        echo
        echo -e "${GREEN}================ 🖥️ 用户界面 ================${NC}"
        echo
        echo -e "${BLUE}1. 安装 hysteria2\n2. 卸载 hysteria2\n3. 退出脚本${NC}"
        echo
        echo -e "${YELLOW}================ 🚀 脚本入口 ================${NC}"
        echo
        read -p "请输入选项 [1-3]: " choice
        case "$choice" in
            1) install_hysteria ;;
            2) uninstall_hysteria "interactive" ;;  # 明确使用交互模式
            3) info "退出脚本"; exit 0 ;;
            *) error "无效选项，请输入数字1-3"
               sleep 1
               continue
               ;;
        esac
        read -p "按回车键返回主菜单..."
    done
}

# ======================== 🚀 脚本入口 ========================
# 处理参数
parse_args "$@"

# 无参数时进入交互菜单
case "$ACTION" in
    install)    install_hysteria ;;
    uninstall)  uninstall_hysteria ;;
    *)          [ $# -eq 0 ] && main_menu || show_help ;;
esac