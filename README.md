# 🚀 Hysteria 部署方案

## 🌟 核心特性

这是Hysteria真正玩法，不是那些装模作样的玩法.......

通过安装
```
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/main/install-warp.sh)
```
完美支持
0.42机器类型:Alpine Linux-LXC容器-IPv6-only-无NAT64网关-wireguard内核支持-客户端root-60G内存-90M磁盘

# 🛠️ 脚本提供了两种安装模式

## 🖥 智能交互模式

使用演示

启动界面：
```

  _   _ _   _ _____ _____ ____  ___ ____  
 | | | | | | |_   _| ____|  _ \|_ _|  _ \ 
 | |_| | | | | | | |  _| | |_) || || |_) |
 |  _  | |_| | | | | |___|  _ < | ||  __/ 
 |_| |_|\___/  |_| |_____|_| \_\___|_|    

Alpine Linux Hysteria2 安装脚本
                                           

================ 🔄 版本控制 ================

最新版本: 2.6.2
本地版本: 2.6.2

================ 🖥️ 用户界面 ================

1. 安装 hysteria2
2. 卸载 hysteria2
3. 退出脚本

================ 🚀 脚本入口 ================

请输入选项 [1-3]

```
安装过程：
```
================ 🚀 脚本入口 ================

请输入选项 [1-3]: 1
[信息] 网络环境检测中......
[成功] 网络环境正常 (IPv4支持)
[成功] 已是最新版 (v2.6.2)
[信息] 正在检测相关依赖...
[成功] openssl已正常安装
请输入监听端口 (默认: 3611): 
请输入密码 (留空将自动生成): 
[信息] 已生成随机密码: ,xtqvQsDky78RVTJTUjP
[信息] 专用用户 hysteria 已存在
[信息] 检测到现有TLS证书，跳过生成
[信息] 检测到现有配置文件，跳过生成
[信息] 正在配置系统服务...
 * WARNING: hysteria has already been started
[成功] 系统服务已配置
Cloudflare检测到IPv6: 2001:41d0:303:3.........
----------------------
最终检测结果：
IPv4: 未检测到IPv4地址
IPv6: 2001:41d0:303:3.............

Hysteria 安装完成！
====================================
以下是节点信息:
hysteria2://,xtqvQso6aYVTJTUjP@未检测到IPv4地址:36711?sni=www.bing.com&alpn=h3&insecure=1#alpine-hysteria
hysteria2://,xtqvQsD aYVTJTUjP@[2001:41d0:303.........]:36711?sni=www.bing.com&alpn=h3&insecure=1#alpine-hysteria-ipv6
====================================
重要提示:
如果你使用ipv6节点信息，请确认客户端支持IPv6连接
====================================
服务管理命令:
启动: /etc/init.d/hysteria start
停止: /etc/init.d/hysteria stop
重启: /etc/init.d/hysteria restart
状态: /etc/init.d/hysteria status
按回车键返回主菜单
```

卸载过程：
```
  _   _ _   _ _____ _____ ____  ___ ____  
 | | | | | | |_   _| ____|  _ \|_ _|  _ \ 
 | |_| | | | | | | |  _| | |_) || || |_) |
 |  _  | |_| | | | | |___|  _ < | ||  __/ 
 |_| |_|\___/  |_| |_____|_| \_\___|_|    

Alpine Linux Hysteria2 安装脚本
====================================
1. 安装 hysteria2
2. 卸载 hysteria2
3. 退出脚本
====================================
请输入选项 [1-3]: 2
[信息] 正在卸载 Hysteria...
 * Stopping hysteria ...                                                                                              [ ok ]
 * service hysteria deleted from runlevel default
[成功] 服务移除
[成功] 可执行文件已删除
[成功] 配置和证书已删除
deluser: can't find hysteria in /etc/group
[成功] 用户已删除
[成功] Hysteria 已卸载
按回车键返回主菜单...

```
这个版本通过交互式菜单实现专业化的安装/卸载管理，同时保持传统脚本的简洁性，所有操作无需记忆参数，适合各种技术水平的用户使用

## 🔧 安装命令

```
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria_menu.sh)
```

注：所有安装脚本会自动清理临时文件，不会在系统中留下冗余数据


# 🚀 极速命令行模式

## 快速查看帮助
```
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria_menu.sh) --help
```
## 快速使用默认配置部署
```
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria_menu.sh) install
```
## 快速卸载方式：
```
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria_menu.sh) uninstall
```