#!/bin/bash
set -euo pipefail

#######################################
# 函数定义区
#######################################

# 显示帮助信息
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

# 安装系统依赖
install_dependencies() {
  for pkg in wget curl git openssh openssl openrc logrotate; do
    apk info | grep -q "^$pkg$" || apk add --no-cache $pkg
  done
}

# 生成随机密码
generate_random_password() {
  openssl rand -base64 18
}

# 生成配置文件内容
generate_config_yaml() {
  local port="${1:-33810}"
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

# 生成OpenRC服务文件
generate_service_file() {
  cat << 'EOF'
#!/sbin/openrc-run
name="hysteria"
command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"
pidfile="/var/run/${name}.pid"
command_background="yes"
stdout_log="/var/log/hysteria.log"
stderr_log="/var/log/hysteria.log"

start_pre() {
    checkpath -d -m 755 -o hysteria /var/log
    checkpath -f -m 640 -o hysteria /var/log/hysteria.log
}

depend() {
    need net
    use dns
    after firewall
}

respawn_delay=5
respawn_max=3
EOF
}

# 配置日志轮转
setup_logrotate() {
  cat > /etc/logrotate.d/hysteria <<EOF
/var/log/hysteria.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 hysteria hysteria
}
EOF
}

# 带重试的下载函数
download_with_retry() {
  local url="$1" dest="$2"
  for i in {1..3}; do
    if wget -O "$dest" "$url" --no-check-certificate; then
      return 0
    fi
    sleep 3
  done
  echo "下载失败: $url" >&2
  return 1
}

# 初始化日志系统
init_log_system() {
  mkdir -p /var/log/
  touch /var/log/hysteria.log
  chown hysteria:hysteria /var/log/hysteria.log
  chmod 640 /var/log/hysteria.log
}

# 生成自签名证书
generate_self_signed_cert() {
  openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name secp384r1) \
    -keyout /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/CN=bing.com" \
    -days 3650
  chmod 600 /etc/hysteria/server.key
  chmod 644 /etc/hysteria/server.crt
}

# 创建系统用户
create_service_user() {
  if ! id hysteria &>/dev/null; then
    adduser -D -S hysteria -G nobody
  fi
}

#######################################
# 主程序执行区
#######################################

main() {
  # 默认值
  local port=33810
  local password="$(generate_random_password)"

  # 解析命令行参数
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

  # 阶段1：环境准备
  install_dependencies
  create_service_user
  
  # 阶段2：下载安装
  local HYSTERIA_VERSION="${HYSTERIA_VERSION:-v2.6.2}"
  download_with_retry \
    "https://github.com/apernet/hysteria/releases/download/${HYSTERIA_VERSION}/hysteria-linux-amd64" \
    /usr/local/bin/hysteria
  chmod +x /usr/local/bin/hysteria

  # 阶段3：配置生成
  mkdir -p /etc/hysteria/
  generate_config_yaml "$port" "$password" > /etc/hysteria/config.yaml
  chmod 640 /etc/hysteria/config.yaml

  # 阶段4：证书生成
  generate_self_signed_cert

  # 阶段5：日志系统
  init_log_system
  setup_logrotate

  # 阶段6：服务安装
  generate_service_file > /etc/init.d/hysteria
  chmod +x /etc/init.d/hysteria
  rc-update add hysteria

  # 阶段7：服务启动
  if ! service hysteria start; then
    echo "服务启动失败" >&2
    tail -n 20 /var/log/hysteria.log || true
    exit 1
  fi

  # 阶段8：输出结果
  cat <<EOF
[成功] Hysteria2 安装完成 (${HYSTERIA_VERSION})
▸ 端口: ${port}
▸ 密码: ${password}
▸ 配置文件: /etc/hysteria/config.yaml
▸ 日志文件: /var/log/hysteria.log

管理命令:
service hysteria [start|stop|restart|status]
tail -f /var/log/hysteria.log
EOF
}

# 执行入口
main "$@"