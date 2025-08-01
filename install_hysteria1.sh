#!/bin/bash
set -euo pipefail

# 全局配置
HYSTERIA_VERSION="v2.6.2"
DEFAULT_PORT=2516
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/hysteria"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

#######################################
# 专业化输出函数
#######################################

header() {
  clear
  echo -e "${BOLD}${BLUE}=== Hysteria 一键管理脚本 ===${NC}"
  echo -e "${BLUE}▪ 版本: ${YELLOW}${HYSTERIA_VERSION}"
  echo -e "${BLUE}▪ 系统: ${YELLOW}$(grep PRETTY_NAME /etc/os-release | cut -d= -f2)${NC}"
  separator
}

separator() {
  echo -e "${BLUE}──────────────────────────────${NC}"
}

success() { echo -e "${GREEN}[✓] ${1}${NC}"; }
error() { echo -e "${RED}[✗] ${1}${NC}"; exit 1; }
warning() { echo -e "${YELLOW}[!] ${1}${NC}"; }
info() { echo -e "${BLUE}[i] ${1}${NC}"; }

#######################################
# 核心功能
#######################################

install() {
  header
  info "开始安装 Hysteria..."
  
  # 交互式配置
  read -p "请输入监听端口 [${DEFAULT_PORT}]: " port
  port=${port:-$DEFAULT_PORT}
  
  read -p "是否自定义密码？(y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "请输入密码: " password
  else
    password=$(openssl rand -base64 18 | tr -d '\n')
    info "已生成随机密码"
  fi

  separator
  info "正在安装系统依赖..."
  for pkg in wget openssl; do
    if ! command -v "$pkg" &>/dev/null; then
      apk add --no-cache "$pkg" >/dev/null || error "依赖安装失败"
    fi
  done

  # 创建专用用户
  if ! id hysteria &>/dev/null; then
    addgroup -S hysteria >/dev/null 2>&1 || warning "创建用户组失败，将使用root运行"
    adduser -S -D -H -G hysteria hysteria >/dev/null 2>&1 || HYSTERIA_USER="root"
  fi

  # 下载核心程序
  info "下载核心组件..."
  wget -q -O "${INSTALL_DIR}/hysteria" \
    "https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/hysteria-linux-amd64" \
    || error "下载失败"
  chmod +x "${INSTALL_DIR}/hysteria"

  # 生成配置文件
  mkdir -p "${CONFIG_DIR}"
  cat > "${CONFIG_DIR}/config.yaml" <<EOF
listen: :${port}
tls:
  cert: ${CONFIG_DIR}/server.crt
  key: ${CONFIG_DIR}/server.key
auth:
  type: password
  password: ${password}
masquerade:
  type: proxy
  proxy:
    url: https://bing.com/
    rewriteHost: true
EOF

  # 生成自签名证书
  openssl ecparam -genkey -name prime256v1 -out "${CONFIG_DIR}/server.key"
  openssl req -new -x509 -days 3650 -key "${CONFIG_DIR}/server.key" \
    -out "${CONFIG_DIR}/server.crt" \
    -subj "/C=US/ST=California/L=San Francisco/O=Hysteria/CN=bing.com"
  chmod 600 "${CONFIG_DIR}/server.key"

  # 配置系统服务
  cat > /etc/init.d/hysteria <<EOF
#!/sbin/openrc-run
name="hysteria"
command="${INSTALL_DIR}/hysteria"
command_args="server --config ${CONFIG_DIR}/config.yaml"
pidfile="/var/run/\${name}.pid"
command_background="yes"

depend() {
    need net
    after firewall
}
EOF
  chmod +x /etc/init.d/hysteria
  rc-update add hysteria >/dev/null
  /etc/init.d/hysteria start >/dev/null || error "服务启动失败"

  # 安装完成输出
  separator
  success "Hysteria 安装完成！"
  echo -e "${BOLD}▸ 监听端口:${NC} ${port}"
  echo -e "${BOLD}▸ 认证密码:${NC} ${password}"
  echo -e "${BOLD}▸ 配置文件:${NC} ${CONFIG_DIR}/config.yaml"
  separator
  echo -e "${BLUE}管理命令:${NC}"
  echo -e "启动服务: rc-service hysteria start"
  echo -e "停止服务: rc-service hysteria stop"
  echo -e "查看状态: rc-service hysteria status"
}

uninstall() {
  header
  warning "即将完全卸载 Hysteria！"
  read -p "确认继续卸载？(y/N) " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || exit 0

  # 停止服务
  if [ -f /etc/init.d/hysteria ]; then
    info "停止运行中的服务..."
    /etc/init.d/hysteria stop >/dev/null 2>&1 || true
    rc-update del hysteria >/dev/null 2>&1 || true
    rm -f /etc/init.d/hysteria
  fi

  # 清理文件
  info "清理系统文件..."
  rm -f "${INSTALL_DIR}/hysteria"
  rm -rf "${CONFIG_DIR}"

  # 删除用户
  if id hysteria &>/dev/null; then
    info "移除专用用户..."
    deluser hysteria >/dev/null 2>&1 || true
    delgroup hysteria >/dev/null 2>&1 || true
  fi

  success "Hysteria 已完全卸载"
}

#######################################
# 主交互界面
#######################################

main_menu() {
  header
  echo -e "${BOLD}请选择操作:${NC}"
  echo
  echo -e "  ${GREEN}1${NC}) 安装 Hysteria"
  echo -e "  ${RED}2${NC}) 卸载 Hysteria"
  echo -e "  ${BLUE}3${NC}) 退出脚本"
  echo
  separator

  read -p "请输入选项 (1-3): " choice
  case $choice in
    1) install ;;
    2) uninstall ;;
    3) exit 0 ;;
    *) error "无效选项";;
  esac
}

# 启动主菜单
while true; do
  main_menu
  read -p "按回车键返回主菜单..." -n 1 -r
done