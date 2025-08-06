#!/bin/ash

# 颜色定义
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
PURPLE='\033[1;35m'
NC='\033[0m' # 无颜色

# 显示带颜色的消息函数
info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

error() {
    echo -e "${RED}[错误]${NC} $1"
}

retry() {
    echo -e "${PURPLE}[重试]${NC} $1"
}

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

# 检查并安装依赖
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

# 获取最新版本号
get_latest_version() {
    info "正在查询最新版本..."
    latest_version=$(wget -qO- https://api.github.com/repos/apernet/hysteria/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$latest_version" ]; then
        error "无法获取最新版本号"
        return 1
    fi
    success "最新版本: $latest_version"
    echo "$latest_version"
    return 0
}

# 安装Hysteria
install_hysteria() {
    # 检查IPv4支持
    check_ipv4 || return 1
    
    # 安装依赖
    install_dependencies || return 1
    
    # 获取用户输入
    info "请输入监听端口 (默认: 443)"
    read -p "端口: " port
    port=${port:-443}
    
    info "请输入密码 (留空将自动生成)"
    read -p "密码: " password
    if [ -z "$password" ]; then
        password=$(openssl rand -base64 18 | tr -d '\n')
        info "已生成随机密码: ${password}"
    fi
    
    # 创建专用用户
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
    
    # 获取最新版本
    latest_version=$(get_latest_version) || return 1
    
    # 检查现有安装
    if [ -f "/usr/local/bin/hysteria" ]; then
        current_version=$(/usr/local/bin/hysteria version | awk '{print $3}')
        if [ "$current_version" = "$latest_version" ]; then
            success "当前已安装最新版本 ($latest_version)，跳过下载"
        else
            warning "发现旧版本 ($current_version)，最新版本为 ($latest_version)"
            read -p "是否更新到最新版本? [y/N] " update_choice
            if [[ "$update_choice" =~ ^[Yy]$ ]]; then
                rm -f /usr/local/bin/hysteria
            else
                info "跳过更新"
            fi
        fi
    fi
    
    # 下载最新版本
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        info "正在下载 hysteria $latest_version..."
        arch=$(uname -m)
        case $arch in
            x86_64) arch="amd64" ;;
            aarch64) arch="arm64" ;;
            *) arch="amd64" ;;
        esac
        
        download_url="https://github.com/apernet/hysteria/releases/download/$latest_version/hysteria-linux-$arch"
        wget -O /usr/local/bin/hysteria "$download_url" || {
            error "下载失败"
            return 1
        }
        chmod +x /usr/local/bin/hysteria
        success "hysteria 下载完成并已安装到 /usr/local/bin/hysteria"
    fi
    
    # 创建配置目录
    mkdir -p /etc/hysteria
    
    # 生成TLS证书
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
    
    # 生成配置文件
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
    
    # 配置系统服务
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
    
    # 显示安装结果
    show_installation_result "$port" "$password"
}

# 显示安装结果
show_installation_result() {
    local port=$1
    local password=$2
    
    # 获取IP地址
    ipv4=$(wget -qO- -4 https://api.ipify.org || echo "你的IPv4地址")
    ipv6=$(wget -qO- -6 https://api.ipify.org || echo "你的IPv6地址")
    
    echo -e "${GREEN}"
    echo "Hysteria 安装完成！"
    echo "===================================="
    echo -e "${NC}"
    echo "以下是节点信息:"
    echo -e "${BLUE}"
    echo "hysteria2://${password}@${ipv4}:${port}?sni=www.bing.com&alpn=h3&insecure=1#alpine-hysteria"
    if [ -n "$ipv6" ] && [ "$ipv6" != "你的IPv6地址" ]; then
        echo "hysteria2://${password}@[${ipv6}]:${port}?sni=www.bing.com&alpn=h3&insecure=1#alpine-hysteria-ipv6"
    fi
    echo -e "${NC}"
    echo "===================================="
    echo "服务管理命令:"
    echo -e "${YELLOW}"
    echo "启动服务: /etc/init.d/hysteria start"
    echo "停止服务: /etc/init.d/hysteria stop"
    echo "重启服务: /etc/init.d/hysteria restart"
    echo "查看状态: /etc/init.d/hysteria status"
    echo -e "${NC}"
}

# 卸载Hysteria
uninstall_hysteria() {
    info "正在卸载 Hysteria..."
    
    # 停止并删除服务
    if [ -f "/etc/init.d/hysteria" ]; then
        /etc/init.d/hysteria stop >/dev/null 2>&1
        rc-update del hysteria >/dev/null 2>&1
        rm -f /etc/init.d/hysteria
        success "服务已移除"
    else
        info "未找到服务文件，跳过服务移除"
    fi
    
    # 删除二进制文件
    if [ -f "/usr/local/bin/hysteria" ]; then
        rm -f /usr/local/bin/hysteria
        success "二进制文件已移除"
    else
        info "未找到二进制文件，跳过移除"
    fi
    
    # 删除配置文件和证书
    if [ -d "/etc/hysteria" ]; then
        rm -rf /etc/hysteria
        success "配置文件和证书已移除"
    else
        info "未找到配置文件目录，跳过移除"
    fi
    
    # 删除用户
    if id "hysteria" >/dev/null 2>&1; then
        deluser hysteria >/dev/null 2>&1
        success "专用用户已移除"
    else
        info "未找到专用用户，跳过移除"
    fi
    
    success "Hysteria 已完全卸载"
}

# 主菜单
main_menu() {
    while true; do
        show_header
        echo -e "${BLUE}"
        echo "1. 安装 hysteria2"
        echo "2. 卸载 hysteria2"
        echo "3. 退出脚本"
        echo -e "${NC}"
        echo "===================================="
        read -p "请输入选项 [1-3]: " choice
        
        case $choice in
            1)
                install_hysteria
                ;;
            2)
                uninstall_hysteria
                ;;
            3)
                info "退出脚本"
                exit 0
                ;;
            *)
                error "选择错误，请重新输入"
                ;;
        esac
        
        read -p "按回车键返回主菜单..."
    done
}

# 脚本入口
main_menu