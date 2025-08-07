# 🚀 Hysteria 部署方案

## 🌟 核心特性

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
====================================
1. 安装 hysteria2
2. 卸载 hysteria2
3. 退出脚本
====================================
请输入选项 [1-3]: 

```
安装过程：
```
请输入选项 [1-3]: 1
[信息] 网络环境检测中......
[成功] 网络环境正常 (IPv4支持)
[信息] 正在检测相关依赖...
[成功] openssl已正常安装
请输入监听端口 (默认: 36711): 
请输入密码 (留空将自动生成): 
[信息] 已生成随机密码: DqxEjjr-ct9SB1JHOVg,yOtk
[信息] 专用用户 hysteria 已存在
[成功] 最新版本: app/v2.6.2
[警告] 发现旧版本 (

lightning
Laboratory

linux/amd64)，最新版本为 (app/v2.6.2)
是否更新到最新版本? [y/N] 
```
管理命令：
```
启动服务: hysteria start
停止服务: hysteria stop
查看状态: hysteria status
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


## 🚀 极速命令行模式

快速查看帮助
```
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/main/install_hysteria_command.sh) help
```
基础部署 (使用默认配置)
```
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria_command.sh)
```
自定义端口部署
```
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria_command.sh) --port 443
```
完全自定义部署
```
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria_command.sh) --port 443 --password "Your$tr0ngP@ss"
```
# 卸载方式：
```
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria_command.sh) uninstall
```


