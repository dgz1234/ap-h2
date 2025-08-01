Hysteria 部署方案
https://raw.githubusercontent.com/apernet/hysteria/master/docs/logo.png

🌟 核心特性
双模式部署架构
模式	命令	适用场景	特点
极速命令行模式	bash <(curl...)	批量部署/CI集成	全自动非交互
智能交互模式	bash <(curl...1.sh)	首次配置/调试	可视化引导

🚀 极速命令行模式

快速查看帮助
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/main/install_hysteria.sh) --help

使用示例

# 传统安装方式：

基础部署 (使用默认配置)
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria.sh)

自定义端口部署
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria.sh) --port 443

完全自定义部署
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria.sh) --port 443 --password "Your$tr0ngP@ss"

# 专业安装方式：
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria.sh) install --port 3017

# 卸载方式：
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria.sh) uninstall


🖥 智能交互模式

使用演示

启动界面：

text
=== Hysteria 一键管理脚本 ===
▪ 版本: v2.6.2
▪ 系统: Alpine Linux 3.18
──────────────────────────────
请选择操作:

1) 安装 Hysteria
2) 卸载 Hysteria
3) 退出脚本

──────────────────────────────
请输入选项 (1-3): 
安装过程：

text
[i] 开始安装 Hysteria...
请输入监听端口 [2516]: 3017
是否自定义密码？(y/N): n
[i] 已生成随机密码
──────────────────────────────
[i] 正在安装系统依赖...
[i] 下载核心组件...
──────────────────────────────
[✓] Hysteria 安装完成！
──────────────────────────────
▸ 监听端口: 3017
▸ 认证密码: Xb8kLm9pQw3zRtY6NvS2
▸ 配置文件: /etc/hysteria/config.yaml
──────────────────────────────
管理命令:
启动服务: rc-service hysteria start
停止服务: rc-service hysteria stop
查看状态: rc-service hysteria status
卸载过程：

text
=== Hysteria 一键管理脚本 ===
[!] 即将完全卸载 Hysteria！
确认继续卸载？(y/N): y
[i] 停止运行中的服务...
[i] 清理系统文件...
[i] 移除专用用户...
[✓] Hysteria 已完全卸载
这个版本通过交互式菜单实现专业化的安装/卸载管理，同时保持传统脚本的简洁性，所有操作无需记忆参数，适合各种技术水平的用户使用

安装命令

bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria1.sh)

注：所有安装脚本会自动清理临时文件，不会在系统中留下冗余数据



