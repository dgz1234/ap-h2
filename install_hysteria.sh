#!/bin/bash
set -euo pipefail

#######################################
# 函数定义区 (兼容BusyBox)
#######################################

show_help() {
  cat <<EOF
Usage: $0 [OPTIONS]
Options:
  --port PORT      设置监听端口 (默认: 33810)
  --password PASS  设置认证密码 (默认: 随机生成)
  --help           显示帮助信息

示例:
  $0 --port 443 --password mypassword
  $0 --port 8080
EOF
  exit 0
}

install_dependencies() {
  echo "正在安装依赖..."
  for pkg in wget curl openssl; do
    if ! command -v "$pkg" &>/dev/null; then
      apk add --no-cache "$pkg"
    fi
  done
}

generate_random_password() {
  openssl rand -base64 18 | tr -d '\n'
}

generate_config_yaml() {
  local port="$1"
  local password="$2"
  cat << EOF
listen: :${port}
log:
  level: info
  output: /var/log/hysteria.log
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

generate_service_file() {
  cat << 'EOF'
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
}

download_with_retry() {
  local url="$1" dest="$2"
  echo "正在下载: $url"
  for i in {1..3}; do
    if wget -O "$dest" "$url"; then
      return 0
    fi
    echo "下载失败 (尝试 $i/3), 3秒后重试..."
    sleep 3
  done
  echo "下载失败: $url" >&2
  return 1
}

create_service_user() {
  if ! id hysteria &>/dev/null; then
    echo "创建用户和组..."
    addgroup hysteria 2>/dev/null || true
    adduser -S -D -H -G hysteria hysteria 2>/dev/null
  fi
}

generate_self_signed_cert() {
  echo "生成证书..."
  mkdir -p /etc/hysteria
  openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
  openssl req -new -x509 -days 3650 -key /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/C=US/ST=California/L=San Francisco/O=Hysteria/CN=bing.com"
  chmod 600 /etc/hysteria/server.key
  chown -R hysteria:hysteria /etc/hysteria
}

init_log_system() {
  touch /var/log/hysteria.log
  chown hysteria:hysteria /var/log/hysteria.log
  chmod 640 /var/log/hysteria.log
}

#######################################
# 主程序
#######################################

main() {
  # 默认值
  local port=33810
  local password="$(generate_random_password)"

  # 解析参数
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
        echo "未知选项: $1" >&2
        show_help
        exit 1
        ;;
    esac
  done

  # 安装流程
  install_dependencies
  create_service_user
  
  # 下载二进制
  download_with_retry \
    "https://github.com/apernet/hysteria/releases/download/app/v2.6.2/hysteria-linux-amd64" \
    /usr/local/bin/hysteria
  chmod +x /usr/local/bin/hysteria

  # 生成配置
  mkdir -p /etc/hysteria
  generate_config_yaml "$port" "$password" > /etc/hysteria/config.yaml
  chown hysteria:hysteria /etc/hysteria/config.yaml
  chmod 640 /etc/hysteria/config.yaml

  # 证书和日志
  generate_self_signed_cert
  init_log_system

  # 服务安装
  generate_service_file > /etc/init.d/hysteria
  chmod +x /etc/init.d/hysteria
  rc-update add hysteria

  # 启动服务
  if ! /etc/init.d/hysteria start; then
    echo "启动失败，查看日志:"
    tail -n 10 /var/log/hysteria.log || true
    exit 1
  fi

  # 输出信息
  cat <<EOF
[成功] Hysteria 安装完成！
▸ 端口: ${port}
▸ 密码: ${password}
▸ 配置文件: /etc/hysteria/config.yaml
▸ 日志文件: /var/log/hysteria.log

管理命令:
启动: rc-service hysteria start
停止: rc-service hysteria stop
状态: rc-service hysteria status
EOF
}

main "$@"