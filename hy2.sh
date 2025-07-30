#!/bin/bash
set -euo pipefail

# 安装依赖（自动跳过已安装的包）
for pkg in wget curl git openssh openssl openrc; do
  apk info | grep -q "^$pkg$" || apk add --no-cache $pkg
done

# 更安全的密码生成
generate_random_password() {
  openssl rand -base64 18
}

GENPASS="$(generate_random_password)"

echo_hysteria_config_yaml() {
  cat << EOF
listen: :${port:-33810}  # 同时监听IPv4和IPv6

log:
  level: info
  output: /var/log/hysteria.log


#有域名，使用CA证书
#acme:
#  domains:
#    - test.heybro.bid #你的域名，需要先解析到服务器ip
#  email: xxx@gmail.com

#使用自签名证书
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $GENPASS

masquerade:
  type: proxy
  proxy:
    url: https://bing.com/
    rewriteHost: true
EOF
}

echo_hysteria_autoStart(){
  local name="hysteria"
  cat << EOF
#!/sbin/openrc-run

name="hysteria"

command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"

pidfile="/var/run/${name}.pid"

command_background="yes"

depend() {
        need networking
}
EOF
}


# 带重试的下载函数
wget_with_retry() {
    local url=$1 dest=$2
    for i in {1..3}; do
        if wget -O "$dest" "$url" --no-check-certificate; then
            return 0
        fi
        sleep 3
    done
    echo "下载失败: $url" >&2
    exit 1
}

# 下载指定版本的二进制
# 示例版本(注释掉)
# HYSTERIA_VERSION="v2.6.1"
HYSTERIA_VERSION="${HYSTERIA_VERSION:-v2.6.1}"
# wget_with_retry "https://github.com/dgz1234/wxy/raw/main/hysteria-linux-amd64-${HYSTERIA_VERSION}" /usr/local/bin/hysteria
chmod +x /usr/local/bin/hysteria

mkdir -p /etc/hysteria/

# 更安全的证书参数
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name secp384r1) \
    -keyout /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/CN=bing.com" \
    -days 3650

#写配置文件
echo_hysteria_config_yaml > "/etc/hysteria/config.yaml"

#写自启动
echo_hysteria_autoStart > "/etc/init.d/hysteria"
chmod +x /etc/init.d/hysteria
#启用自启动
rc-update add hysteria

service hysteria start || {
    echo "服务启动失败" >&2
    journalctl -u hysteria --no-pager -n 20
    exit 1
}

# 设置清理陷阱
trap 'rm -f /tmp/hysteria_temp*' EXIT

cat <<EOF
[成功] Hysteria2 安装完成 (${HYSTERIA_VERSION})
▸ 端口: ${port:-33810}
▸ 密码: $GENPASS
▸ TLS SNI: bing.com
▸ 配置文件: /etc/hysteria/config.yaml
▸ 日志文件: /var/log/hysteria.log

管理命令:
service hysteria [start|stop|restart|status]
journalctl -u hysteria -f  # 查看日志

EOF
