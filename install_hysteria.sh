#!/bin/bash
set -euo pipefail

# 版本配置
HYSTERIA_VERSION="v2.6.2"
DEFAULT_PORT=2516

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#######################################
# 美化输出函数
#######################################

info() {
  echo -e "${BLUE}[ℹ] ${1}${NC}"
}

success() {
  echo -e "${GREEN}[✓] ${1}${NC}"
}

warning() {
  echo -e "${YELLOW}[⚠] ${1}${NC}"
}

error() {
  echo -e "${RED}[✗] ${1}${NC}"
}

#######################################
# 核心功能函数
#######################################

show_help() {
  cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  install      安装Hysteria (默认操作)
  uninstall   完全卸载Hysteria
  help        显示帮助信息

Install Options:
  --port PORT      设置监听端口 (默认: ${DEFAULT_PORT})
  --password PASS  设置认证密码 (默认: 随机生成)

示例:
  $0 install --port 443 --password mypassword
  $0 uninstall
EOF
  exit 0
}

create_service_user() {
  deluser hysteria 2>/dev/null || true
  delgroup hysteria 2>/dev/null || true

  if ! grep -q "^hysteria:" /etc/group; then
    addgroup -S hysteria || {
      error "无法创建hysteria组"
      return 1
    }
  fi

  adduser -S -D -H -G hysteria hysteria || {
    error "无法创建hysteria用户"
    return 1
  }
}

generate_password() {
  openssl rand -base64 18 | tr -d '\n'
}

generate_config() {
  local port="$1"
  local password="$2"
  cat <<EOF
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
}

generate_cert() {
  openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
  openssl req -new -x509 -days 3650 -key /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/C=US/ST=California/L=San Francisco/O=Hysteria/CN=bing.com"
  chmod 600 /etc/hysteria/server.key
}

create_service() {
  cat > /etc/init.d/hysteria <<'EOF'
#!/sbin/openrc-run
name="hysteria"
command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"
pidfile="/var/run/${name}.pid"
command_background="yes"

depend() {
    need net
    after firewall
}
EOF
  chmod +x /etc/init.d/hysteria
}

#######################################
# 安装功能
#######################################

install_hysteria() {
  local port="$DEFAULT_PORT"
  local password="$(generate_password)"
  
  # 参数解析
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port) port="$2"; shift 2 ;;
      --password) password="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  info "=== 正在安装Hysteria ==="
  
  # 安装依赖
  for pkg in wget openssl; do
    if ! command -v "$pkg" &>/dev/null; then
      info "正在安装依赖: $pkg..."
      apk add --no-cache "$pkg" || {
        error "依赖安装失败"
        exit 1
      }
    fi
  done

  # 创建用户
  if ! create_service_user; then
    warning "将使用root用户运行服务"
    HYSTERIA_USER="root"
  else
    HYSTERIA_USER="hysteria"
  fi
  
  # 下载二进制
  info "下载二进制文件 (v${HYSTERIA_VERSION})..."
  wget -q -O /usr/local/bin/hysteria \
    "https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/hysteria-linux-amd64" || {
    error "下载失败"
    exit 1
  }
  chmod +x /usr/local/bin/hysteria

  # 生成配置
  info "生成配置文件..."
  mkdir -p /etc/hysteria
  generate_config "$port" "$password" > /etc/hysteria/config.yaml
  generate_cert

  # 设置权限
  info "设置文件权限..."
  chown -R "${HYSTERIA_USER:-root}:hysteria" /etc/hysteria
  chmod 640 /etc/hysteria/config.yaml

  # 配置服务
  info "配置服务..."
  create_service
  rc-update add hysteria >/dev/null

  # 启动服务
  info "启动服务..."
  if ! /etc/init.d/hysteria start; then
    error "服务启动失败"
    exit 1
  fi

  # 输出结果
  success "安装成功！"
  echo -e "
  ${BLUE}▸ 监听端口: ${YELLOW}${port}
  ${BLUE}▸ 认证密码: ${YELLOW}${password}
  ${BLUE}▸ 配置文件: ${YELLOW}/etc/hysteria/config.yaml${NC}

  ${GREEN}管理命令:${NC}
  ${BLUE}启动: ${NC}rc-service hysteria start
  ${BLUE}停止: ${NC}rc-service hysteria stop
  ${BLUE}状态: ${NC}rc-service hysteria status
  "
}

#######################################
# 卸载功能
#######################################

uninstall_hysteria() {
  info "=== 正在卸载Hysteria ==="
  
  # 停止服务
  if [ -f /etc/init.d/hysteria ]; then
    info "停止服务..."
    /etc/init.d/hysteria stop 2>/dev/null || true
    rc-update del hysteria 2>/dev/null || true
    rm -f /etc/init.d/hysteria
  fi

  # 删除用户
  info "清理用户..."
  deluser hysteria 2>/dev/null || true
  delgroup hysteria 2>/dev/null || true

  # 删除文件
  info "删除文件..."
  rm -f /usr/local/bin/hysteria
  rm -rf /etc/hysteria

  success "卸载完成！所有相关文件已清理"
}

#######################################
# 主流程
#######################################

main() {
  case "${1:-install}" in
    install)
      shift
      install_hysteria "$@"
      ;;
    uninstall)
      uninstall_hysteria
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      error "未知命令: $1"
      show_help
      exit 1
      ;;
  esac
}

main "$@"