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
# 系统依赖检查与安装
#######################################

check_and_install_deps() {
  info "正在检查系统依赖..."
  local missing_deps=()
  
  # 检查必要依赖
  for pkg in wget openssl; do
    if ! command -v "$pkg" &>/dev/null; then
      missing_deps+=("$pkg")
    fi
  done

  if [ ${#missing_deps[@]} -gt 0 ]; then
    info "正在安装缺失依赖: ${missing_deps[*]}..."
    if ! apk add --no-cache "${missing_deps[@]}" >/dev/null; then
      error "依赖安装失败"
    fi
    success "依赖安装完成"
  else
    info "所有必要依赖已安装"
  fi
}

#######################################
# 核心功能
#######################################

install() {
  header
  info "开始安装 Hysteria..."
  
  # 检查并安装依赖
  check_and_install_deps
  separator
  
  # 交互式配置
  info "正在配置监听端口..."
  read -p "请输入监听端口 [${DEFAULT_PORT}]: " port
  port=${port:-$DEFAULT_PORT}
  success "端口设置完成: ${port}"
  
  info "正在配置认证密码..."
  read -p "是否自定义密码？(y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "请输入密码: " password
    success "已设置自定义密码"
  else
    password=$(openssl rand -base64 18 | tr -d '\n')
    success "已生成随机密码"
  fi

  separator
  info "正在创建专用用户..."
  if ! id hysteria &>/dev/null; then
    if addgroup -S hysteria >/dev/null 2>&1; then
      if adduser -S -D -H -G hysteria hysteria >/dev/null 2>&1; then
        success "专用用户创建成功"
      else
        warning "创建用户失败，将使用root运行"
        HYSTERIA_USER="root"
      fi
    else
      warning "创建用户组失败，将使用root运行"
      HYSTERIA_USER="root"
    fi
  else
    info "专用用户已存在"
  fi

  # 下载核心程序
  separator
  info "正在下载核心组件..."
  if wget -q -O "${INSTALL_DIR}/hysteria" \
    "https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/hysteria-linux-amd64"; then
    chmod +x "${INSTALL_DIR}/hysteria"
    success "核心组件下载完成"
  else
    error "下载失败"
  fi

  # 生成配置文件
  info "正在生成配置文件..."
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
  success "配置文件已生成: ${CONFIG_DIR}/config.yaml"

  # 生成自签名证书
  info "正在生成TLS证书..."
  if openssl ecparam -genkey -name prime256v1 -out "${CONFIG_DIR}/server.key" && \
     openssl req -new -x509 -days 3650 -key "${CONFIG_DIR}/server.key" \
       -out "${CONFIG_DIR}/server.crt" \
       -subj "/C=US/ST=California/L=San Francisco/O=Hysteria/CN=bing.com"; then
    chmod 600 "${CONFIG_DIR}/server.key"
    success "TLS证书生成完成"
  else
    error "证书生成失败"
  fi

  # 配置系统服务
  info "正在配置系统服务..."
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
  success "系统服务配置完成"

  # 启动服务
  info "正在启动服务..."
  if /etc/init.d/hysteria start >/dev/null; then
    success "服务启动成功"
  else
    error "服务启动失败"
  fi

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
    info "正在停止运行中的服务..."
    if /etc/init.d/hysteria stop >/dev/null 2>&1; then
      success "服务已停止"
    else
      warning "停止服务失败，可能服务未运行"
    fi
    rc-update del hysteria >/dev/null 2>&1 || true
    rm -f /etc/init.d/hysteria
    success "服务配置已移除"
  else
    info "未找到服务配置"
  fi

  # 清理文件
  info "正在清理系统文件..."
  if [ -f "${INSTALL_DIR}/hysteria" ]; then
    rm -f "${INSTALL_DIR}/hysteria"
    success "核心程序已移除"
  else
    info "未找到核心程序"
  fi
  
  if [ -d "${CONFIG_DIR}" ]; then
    rm -rf "${CONFIG_DIR}"
    success "配置文件已移除"
  else
    info "未找到配置文件"
  fi

  # 删除用户
  if id hysteria &>/dev/null; then
    info "正在移除专用用户..."
    if deluser hysteria >/dev/null 2>&1; then
      delgroup hysteria >/dev/null 2>&1 || true
      success "专用用户已移除"
    else
      warning "移除用户失败"
    fi
  else
    info "未找到专用用户"
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