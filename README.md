# Hysteria 终极部署工具

![Hysteria Logo](https://raw.githubusercontent.com/apernet/hysteria/master/docs/logo.png)

## 🌟 核心特性

### 双模式部署架构
| 模式 | 命令 | 适用场景 | 特点 |
|------|------|----------|------|
| **极速命令行模式** | `bash <(curl...)` | 批量部署/CI集成 | 全自动非交互 |
| **智能交互模式** | `bash <(curl...1.sh)` | 首次配置/调试 | 可视化引导 |

## 🚀 极速命令行模式

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dgz1234/ap-h2/refs/heads/main/install_hysteria.sh) [OPTIONS]