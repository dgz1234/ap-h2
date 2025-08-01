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
  echo "正在安装系统依赖..."
  local pkg
  for pkg in wget curl openssl; do
    if ! command -v "$pkg" &>/dev/null; then
      if command -v apk &>/dev/null; then
        apk add --no-cache "$pkg"
      elif command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y "$pkg"
      elif command -v yum &>/dev/null; then
        yum install -y "$pkg"
      else
        echo "无法确定包管理器，请手动安装 $pkg"
        exit 1
      fi
    fi
  done
}

# 生成随机密码
generate_random_password() {
  openssl rand -base64 18 | tr -d '\n'
}

# 生成配置文件内容
generate_config_yaml() {
  local port="${1:-33810}"
  local password="$2"
  cat << EOF
listen: :${port}
log:
  level: info
  output: /var/log/hysteria/hysteria.log
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
description="Hysteria VPN Service"
command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"
command_background="yes"
pidfile="/var/run/${name}.pid"

start_pre() {
    checkpath -d -m 755 -o hysteria:hysteria /var/log/hysteria
    checkpath -f -m 640 -o hysteria:hysteria /var/log/hysteria/hysteria.log
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
  echo "配置日志轮转..."
  mkdir -p /etc/logrotate.d/
  cat > /etc/logrotate.d/hysteria <<EOF
/var/log/hysteria/hysteria.log {
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
  echo "正在下载: $url"
  for i in {1..3}; do
    if wget --no-check-certificate -O "$dest" "$url"; then
      return 0
    fi
    echo "下载失败 (尝试 $i/3), 3秒后重试..."
    sleep 3
  done
  echo "下载失败: $url" >&2
  return 1
}

# 初始化日志系统
init_log_system() {
  echo "初始化日志系统..."
  mkdir -p /var/log/hysteria/
  touch /var/log/hysteria/hysteria.log
  chown -R hysteria:hysteria /var/log/hysteria/
  chmod -R 750 /var/log/hysteria/
  chmod 640 /var/log/hysteria/hysteria.log
}

# 生成自签名证书
generate_self_signed_cert() {
  echo "生成自签名证书..."
  mkdir -p /etc/hysteria/
  
  # 生成私钥
  openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
  
  # 生成证书
  openssl req -new -x509 -days 3650 -key /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/C=US/ST=California/L=San Francisco/O=Hysteria/CN=bing.com"
  
  chmod 600 /etc/hysteria/server.key
  chmod 644 /etc/hysteria/server.crt
  chown -R hysteria:hysteria /etc/hysteria/
}

# 创建系统用户
create_service_user() {
  echo "创建系统用户..."
  if ! id hysteria &>/dev/null; then
    if command -v adduser &>/dev/null; then
      adduser --system --no-create-home --disabled-password --group hysteria
    elif command -v useradd &>/dev/null; then
      useradd --system --no-create-home --shell /usr/sbin/nologin hysteria
    else
      echo "无法创建用户，请手动创建 hysteria 用户"
      exit 1
    fi
  fi
}

# 检查端口是否可用
check_port() {
  local port="$1"
  if command -v ss &>/dev/null; then
    if ss -tuln | grep -q ":$port "; then
      echo "错误: 端口 $port 已被占用"
      exit 1
    fi
  elif command -v netstat &>/dev/null; then
    if netstat -tuln | grep -q ":$port "; then
      echo "错误: 端口 $port 已被占用"
      exit 1
    fi
  else
    echo "警告: 无法检查端口占用情况，请确保端口 $port 可用"
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

  # 检查端口
  check_port "$port"

  # 阶段1：环境准备
  install_dependencies
  create_service_user
  
  # 阶段2：下载安装
  local HYSTERIA_VERSION="${HYSTERIA_VERSION:-v2.6.2}"
  download_with_retry \
    "https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/hysteria-linux-amd64" \
    /usr/local/bin/hysteria
  chmod +x /usr/local/bin/hysteria

  # 阶段3：配置生成
  mkdir -p /etc/hysteria/
  generate_config_yaml "$port" "$password" > /etc/hysteria/config.yaml
  chmod 640 /etc/hysteria/config.yaml
  chown hysteria:hysteria /etc/hysteria/config.yaml

  # 阶段4：证书生成
  generate_self_signed_cert

  # 阶段5：日志系统
  init_log_system
  setup_logrotate

  # 阶段6：服务安装
  echo "安装服务..."
  generate_service_file > /etc/init.d/hysteria
  chmod +x /etc/init.d/hysteria
  
  if command -v rc-update &>/dev/null; then
    rc-update add hysteria
  elif command -v systemctl &>/dev/null; then
    cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=Hysteria VPN Service
After=network.target

[Service]
User=hysteria
Group=hysteria
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=always
RestartSec=5
LimitNOFILE=infinity
StandardOutput=file:/var/log/hysteria/hysteria.log
StandardError=file:/var/log/hysteria/hysteria.log

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable hysteria
  else
    echo "警告: 无法自动配置服务启动，请手动设置"
  fi

  # 阶段7：服务启动
  echo "启动服务..."
  if command -v rc-service &>/dev/null; then
    rc-service hysteria start
  elif command -v systemctl &>/dev/null; then
    systemctl start hysteria
  else
    echo "警告: 无法自动启动服务，请手动运行:"
    echo "/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml"
  fi

  # 阶段8：输出结果
  cat <<EOF

[成功] Hysteria2 安装完成 (${HYSTERIA_VERSION})
▸ 监听端口: ${port}
▸ 认证密码: ${password}
▸ 配置文件: /etc/hysteria/config.yaml
▸ 日志文件: /var/log/hysteria/hysteria.log

管理命令:
启动: rc-service hysteria start   或 systemctl start hysteria
停止: rc-service hysteria stop   或 systemctl stop hysteria
状态: rc-service hysteria status 或 systemctl status hysteria
日志: tail -f /var/log/hysteria/hysteria.log

EOF
}

# 执行入口
main "$@"