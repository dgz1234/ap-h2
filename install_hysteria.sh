#!/bin/bash
set -euo pipefail

# 版本配置
HYSTERIA_VERSION="v2.6.2"
DEFAULT_PORT=2516

#######################################
# 函数定义 (兼容Alpine/BusyBox)
#######################################

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

create_service_user() {
  deluser hysteria 2>/dev/null || true
  delgroup hysteria 2>/dev/null || true

  if ! grep -q "^hysteria:" /etc/group; then
    addgroup -S hysteria || {
      echo "❌ 无法创建hysteria组" >&2
      return 1
    }
  fi

  adduser -S -D -H -G hysteria hysteria || {
    echo "❌ 无法创建hysteria用户" >&2
    return 1
  }

  if ! id hysteria &>/dev/null; then
    echo "⚠️ 警告：将使用root用户运行服务（非推荐）" >&2
    return 1
  fi
}

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

generate_password() {
  openssl rand -base64 18 | tr -d '\n'
}

# 修改点1：增强日志配置
generate_config() {
  local port="$1"
  local password="$2"
  cat <<EOF
listen: :${port}
log:
  level: debug       # 改为debug级别确保输出所有日志
  format: text       # 文本格式更易读
  output: /var/log/hysteria/hysteria.log  # 使用专用日志目录
  flush_interval: 1s # 强制每秒刷新日志
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

# 修改点2：更新服务文件中的日志路径
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
    checkpath -f -m 640 -o hysteria /var/log/hysteria/hysteria.log  # 修正日志路径
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
  local port="$DEFAULT_PORT"
  local password="$(generate_password)"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port) port="$2"; shift 2 ;;
      --password) password="$2"; shift 2 ;;
      --help) show_help ;;
      *) echo "❌ 未知选项: $1" >&2; show_help; exit 1 ;;
    esac
  done

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

  # 修改点3：初始化日志系统
  echo "→ 初始化日志系统..."
  mkdir -p /var/log/hysteria
  touch /var/log/hysteria/hysteria.log
  chown -R "${HYSTERIA_USER:-hysteria}:hysteria" /var/log/hysteria
  chmod 750 /var/log/hysteria
  chmod 640 /var/log/hysteria/hysteria.log

  echo "→ 设置文件权限..."
  chown -R "${HYSTERIA_USER:-hysteria}:hysteria" /etc/hysteria
  chmod 640 /etc/hysteria/config.yaml

  echo "→ 配置服务..."
  create_service
  rc-update add hysteria

  echo "→ 启动服务..."
  if ! /etc/init.d/hysteria start; then
    echo "❌ 服务启动失败" >&2
    journalctl -u hysteria -n 10 --no-pager || true
    exit 1
  fi

  # 修改点4：添加日志验证提示
  cat <<EOF

✅ 安装成功！
▸ 监听端口: ${port}
▸ 认证密码: ${password}
▸ 配置文件: /etc/hysteria/config.yaml
▸ 日志文件: /var/log/hysteria/hysteria.log

管理命令:
启动: rc-service hysteria start
停止: rc-service hysteria stop
状态: rc-service hysteria status
日志跟踪: tail -f /var/log/hysteria/hysteria.log

等待10秒后自动显示日志头...
EOF
  sleep 10
  echo "=== 日志文件开头 ==="
  head -n 20 /var/log/hysteria/hysteria.log || echo "⚠️ 暂无日志输出，请尝试访问服务生成日志"
}

main "$@"