#!/bin/bash
set -euo pipefail

# 版本配置
HYSTERIA_VERSION="v2.6.2"
DEFAULT_PORT=2516

#######################################
# 函数定义 (兼容Alpine/BusyBox)
#######################################

# 显示帮助信息
show_help() {
  cat <<EOF
Usage: $0 [OPTIONS]
Options:
  --port PORT      设置监听端口 (默认: ${DEFAULT_PORT})
  --password PASS  设置认证密码 (默认: 随机生成)
  --help           显示帮助信息

示例:
  $0 --port 443 --password mypassword
  $0 --port 8080
EOF
  exit 0
}

# 创建系统用户和组
create_service_user() {
  # 清理可能存在的旧配置
  deluser hysteria 2>/dev/null || true
  delgroup hysteria 2>/dev/null || true

  # 创建组
  if ! grep -q "^hysteria:" /etc/group; then
    addgroup -S hysteria || {
      echo "❌ 无法创建hysteria组" >&2
      return 1
    }
  fi

  # 创建用户
  adduser -S -D -H -G hysteria hysteria || {
    echo "❌ 无法创建hysteria用户" >&2
    return 1
  }

  # 验证
  if ! id hysteria &>/dev/null; then
    echo "⚠️ 警告：将使用root用户运行服务（非推荐）" >&2
    return 1
  fi
}

# 安装系统依赖
install_dependencies() {
  for pkg in wget openssl; do
    if ! command -v "$pkg" &>/dev/null; then
      echo "正在安装依赖: $pkg..."
      apk add --no-cache "$pkg" || {
        echo "❌ 依赖安装失败" >&2
        exit 1
      }
    fi
  done
}

# 生成随机密码
generate_password() {
  openssl rand -base64 18 | tr -d '\n'
}

# 生成配置文件
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

# 生成自签名证书
generate_cert() {
  openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
  openssl req -new -x509 -days 3650 -key /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/C=US/ST=California/L=San Francisco/O=Hysteria/CN=bing.com"
  chmod 600 /etc/hysteria/server.key
}

# 创建OpenRC服务
create_service() {
  cat > /etc/init.d/hysteria <<'EOF'
#!/sbin/openrc-run
name="hysteria"
command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"
pidfile="/var/run/${name}.pid"
command_background="yes"

start_pre() {
    checkpath -d -m 755 -o hysteria /var/log/hysteria
    checkpath -f -m 640 -o hysteria /var/log/hysteria.log
}

depend() {
    need net
    after firewall
}
EOF
  chmod +x /etc/init.d/hysteria
}

#######################################
# 主安装流程
#######################################

main() {
  # 参数解析
  local port="$DEFAULT_PORT"
  local password="$(generate_password)"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port)
        port="$2"
        shift 2
        ;;
      --password)
        password="$2"
        shift 2
        ;;
      --help)
        show_help
        ;;
      *)
        echo "❌ 未知选项: $1" >&2
        show_help
        exit 1
        ;;
    esac
  done

  # 安装流程
  echo "=== 正在安装Hysteria ==="
  install_dependencies
  create_service_user || HYSTERIA_USER="root"
  
  echo "→ 下载二进制文件 (v${HYSTERIA_VERSION})..."
  wget -O /usr/local/bin/hysteria \
    "https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/hysteria-linux-amd64" || {
    echo "❌ 下载失败" >&2
    exit 1
  }
  chmod +x /usr/local/bin/hysteria

  echo "→ 生成配置文件..."
  mkdir -p /etc/hysteria
  generate_config "$port" "$password" > /etc/hysteria/config.yaml
  generate_cert

  echo "→ 设置文件权限..."
  chown -R "${HYSTERIA_USER:-hysteria}:hysteria" /etc/hysteria
  chmod 640 /etc/hysteria/config.yaml

  echo "→ 配置服务..."
  create_service
  rc-update add hysteria

  # 启动服务
  echo "→ 启动服务..."
  if ! /etc/init.d/hysteria start; then
    echo "❌ 服务启动失败" >&2
    journalctl -u hysteria -n 10 --no-pager || true
    exit 1
  fi

  # 输出结果
  cat <<EOF

✅ 安装成功！
▸ 监听端口: ${port}
▸ 认证密码: ${password}
▸ 配置文件: /etc/hysteria/config.yaml

管理命令:
启动: rc-service hysteria start
停止: rc-service hysteria stop
状态: rc-service hysteria status
日志: tail -f /var/log/hysteria.log
EOF
}

main "$@"