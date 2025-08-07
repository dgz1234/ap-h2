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

# 显示大标题
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
    echo "===================================="
}
# ======================== 🔧 工具函数 ========================
# 检查IPv4支持
check_ipv4() {
    info "网络环境检测中......"
    if ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
        success "网络环境正常 (IPv4支持)"
        return 0
    else
        error "您的网络需要IPv4支持"
        warning "如果您使用的是LXC容器-IPv6-only-无NAT64网关，建议先安装WARP"
        return 1
    fi
}

# 安装依赖
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

# 获取最新版本号（只输出干净版本号，不含颜色或日志）
# 修改 get_latest_version 函数
get_latest_version() {
    temp_file=$(mktemp)
    if ! wget -qO- https://api.github.com/repos/apernet/hysteria/releases/latest > "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi
    # 更精确的版本提取方法
    latest_version=$(grep '"tag_name":' "$temp_file" | cut -d'"' -f4 | sed 's/^v//')
    rm -f "$temp_file"
    if [ -z "$latest_version" ]; then
        return 1
    fi
    echo "$latest_version"
    return 0
}

# 安装 hysteria
install_hysteria() {
    check_ipv4 || return 1
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

    latest_version=$(get_latest_version)
    if [ -z "$latest_version" ]; then
        error "无法获取最新版本"
        return 1
    fi
    success "最新版本: $latest_version"

    if [ -f "/usr/local/bin/hysteria" ]; then
        current_version=$(/usr/local/bin/hysteria version 2>/dev/null | head -n 1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
        if [ -n "$current_version" ]; then
            # 标准化最新版本号（去除app/v前缀）
            clean_latest_version=$(echo "$latest_version" | sed 's/^app\/v//')

            if [ "$current_version" = "$clean_latest_version" ]; then
                success "当前已安装最新版本 ($clean_latest_version)，跳过下载"
            else
                warning "发现旧版本 ($current_version)，最新版本为 ($clean_latest_version)"
                read -p "是否更新到最新版本? [y/N] " update_choice
                if [[ "$update_choice" =~ ^[Yy]$ ]]; then
                    rm -f /usr/local/bin/hysteria
                else
                    info "跳过更新"
                    return 0
                fi
            fi
        fi
    fi

    if [ ! -f "/usr/local/bin/hysteria" ]; then
        info "正在下载 hysteria $latest_version..."
        arch=$(uname -m)
        case $arch in
            x86_64) arch="amd64" ;;
            aarch64) arch="arm64" ;;
            *) arch="amd64" ;;
        esac

        download_url="https://github.com/apernet/hysteria/releases/download/${latest_version}/hysteria-linux-${arch}"
        info "下载地址: $download_url"

        wget -O /usr/local/bin/hysteria "$download_url" || {
            error "下载失败"
            return 1
        }
        chmod +x /usr/local/bin/hysteria
        success "hysteria 下载完成并已安装到 /usr/local/bin/hysteria"
    fi

    mkdir -p /etc/hysteria

    if [ ! -f "/etc/hysteria/server.key" ] || [ ! -f "/etc/hysteria/server.crt" ]; then
        info "正在生成自签名证书..."
        openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
        openssl req -new -x509 -days 36500 -key /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=www.bing.com"
        chown hysteria:hysteria /etc/hysteria/server.key /etc/hysteria/server.crt
        chmod 600 /etc/hysteria/server.key
        success "自签名证书已生成"
    else
        info "检测到现有TLS证书，跳过生成"
    fi

    if [ ! -f "/etc/hysteria/config.yaml" ]; then
        info "正在生成配置文件..."
        cat > /etc/hysteria/config.yaml <<EOF
listen: :${port}
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
auth:
  type: password
  password: ${password}
masquerade:
  type: proxy
  proxy:
    url: https://bing.com/
    rewriteHost: true
EOF
        chown hysteria:hysteria /etc/hysteria/config.yaml
        success "配置文件已生成"
    else
        info "检测到现有配置文件，跳过生成"
    fi

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

    show_installation_result "$port" "$password"
}

# 显示安装结果
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
    echo "启动: /etc/init.d/hysteria start"
    echo "停止: /etc/init.d/hysteria stop"
    echo "重启: /etc/init.d/hysteria restart"
    echo "状态: /etc/init.d/hysteria status"
}

# 卸载 hysteria
uninstall_hysteria() {
    info "正在卸载 Hysteria..."
    [ -f /etc/init.d/hysteria ] && /etc/init.d/hysteria stop && rc-update del hysteria && rm -f /etc/init.d/hysteria && success "服务移除"
    [ -f /usr/local/bin/hysteria ] && rm -f /usr/local/bin/hysteria && success "可执行文件已删除"
    [ -d /etc/hysteria ] && rm -rf /etc/hysteria && success "配置和证书已删除"
    id hysteria >/dev/null 2>&1 && deluser hysteria && success "用户已删除"
    success "Hysteria 已卸载"
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
