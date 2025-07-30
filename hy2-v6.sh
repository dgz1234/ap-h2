#!/bin/bash

# 安装依赖
apk add --no-cache wget curl openssl openrc

# 生成随机密码
generate_random_password() {
  dd if=/dev/random bs=18 count=1 status=none | base64
}

GENPASS="$(generate_random_password)"
PORT="${port:-33810}"

# 配置文件模板
cat > /etc/hysteria/config.yaml <<EOF
listen: "[::]:$PORT"  # 强制IPv6监听
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
auth:
  type: password
  password: "$GENPASS"
# 可选：禁用伪装测试（需IPv6网络支持）
# masquerade:
#   type: proxy
#   proxy:
#     url: https://ipv6.google.com  # 使用支持IPv6的目标
#     rewriteHost: true
EOF

# 自签名证书（简化命令）
openssl ecparam -name prime256v1 -genkey -out /etc/hysteria/server.key
openssl req -x509 -nodes -key /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500

# 下载二进制（重试机制）
for i in {1..3}; do
  wget -O /usr/local/bin/hysteria "https://github.com/dgz1234/wxy/raw/main/hysteria-linux-amd64" \
    --no-check-certificate && break || sleep 5
done
chmod +x /usr/local/bin/hysteria

# 服务启动脚本
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
rc-update add hysteria
service hysteria start

# 输出信息
cat <<EOF
------------------------------------------------------------------------
Hysteria2 安装完成！
* IPv6 地址: [$(ip -6 addr show scope global | grep -oE '[0-9a-f:]+' | head -n 1)]:$PORT
* 密码: $GENPASS
* TLS SNI: bing.com
* 配置文件: /etc/hysteria/config.yaml
* 查看状态: service hysteria status
* 重启服务: service hysteria restart
------------------------------------------------------------------------
EOF

# 手动验证（可选）
echo "正在测试服务..."
sleep 3
service hysteria status