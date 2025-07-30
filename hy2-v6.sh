#!/bin/bash

# 安装依赖（跳过已安装的包）
apk add --no-cache wget curl openssl openrc

# 生成随机密码
generate_random_password() {
  dd if=/dev/random bs=18 count=1 status=none | base64
}

GENPASS="$(generate_random_password)"
PORT="${port:-2516}"

# 下载 Hysteria 二进制（使用备用 IPv6 镜像）
HYSTERIA_URL="https://mirror.ghproxy.com/https://github.com/dgz1234/wxy/raw/main/hysteria-linux-amd64"
for i in {1..3}; do
  wget -O /usr/local/bin/hysteria "$HYSTERIA_URL" --no-check-certificate && break || sleep 5
done

if [ ! -f /usr/local/bin/hysteria ]; then
  echo "错误：无法下载 Hysteria 二进制文件！请检查网络或手动上传。"
  exit 1
fi
chmod +x /usr/local/bin/hysteria

# 生成 TLS 证书
mkdir -p /etc/hysteria
openssl ecparam -name prime256v1 -genkey -out /etc/hysteria/server.key
openssl req -x509 -nodes -key /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500

# 配置文件（强制 IPv6 监听，禁用伪装测试）
cat > /etc/hysteria/config.yaml <<EOF
listen: "[::]:$PORT"
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
auth:
  type: password
  password: "$GENPASS"
EOF

# 服务管理脚本
cat > /etc/init.d/hysteria <<EOF
#!/sbin/openrc-run
name="hysteria"
command="/usr/local/bin/hysteria"
command_args="server --config /etc/hysteria/config.yaml"
pidfile="/var/run/\${name}.pid"
command_background="yes"
depend() {
  need networking
}
EOF
chmod +x /etc/init.d/hysteria

# 启动服务
rc-update add hysteria 2>/dev/null
service hysteria restart

# 输出信息
IPV6_ADDR=$(ip -6 addr show scope global | grep -oE '[0-9a-f:]+' | head -n 1)
cat <<EOF
------------------------------------------------------------------------
Hysteria2 安装完成！
* IPv6 地址: [$IPV6_ADDR]:$PORT
* 密码: $GENPASS
* TLS SNI: bing.com
* 配置文件: /etc/hysteria/config.yaml
* 调试命令: /usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
------------------------------------------------------------------------
EOF

# 等待服务启动并检查状态
sleep 3
service hysteria status || {
  echo "服务启动失败！手动调试命令："
  echo "/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml"
}