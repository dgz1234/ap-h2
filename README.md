# Hysteria 部署方案

## █ 模式对比卡片

<div style="display: flex; justify-content: space-between; margin: 2em 0;">

<div style="width: 48%; border: 1px solid #30363d; border-radius: 6px; padding: 16px; background-color: #0d1117;">
<h3 style="color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 8px;">🚀 极速命令行模式</h3>
<pre style="background-color: #161b22; padding: 12px; border-radius: 6px; overflow-x: auto;">
<span style="color: #79c0ff;">bash</span> <(curl -fsSL https://raw.githubusercontent.com/.../install_hysteria.sh)</pre>
<ul style="padding-left: 20px; color: #c9d1d9;">
<li><strong>适用场景：</strong>CI/CD 流水线、批量部署</li>
<li><strong>核心优势：</strong>30秒极速完成</li>
<li><strong>交互方式：</strong>全自动非交互</li>
</ul>
</div>

<div style="width: 48%; border: 1px solid #30363d; border-radius: 6px; padding: 16px; background-color: #0d1117;">
<h3 style="color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 8px;">🖥 智能交互模式</h3>
<pre style="background-color: #161b22; padding: 12px; border-radius: 6px; overflow-x: auto;">
<span style="color: #79c0ff;">bash</span> <(curl -fsSL https://raw.githubusercontent.com/.../install_hysteria1.sh)</pre>
<ul style="padding-left: 20px; color: #c9d1d9;">
<li><strong>适用场景：</strong>首次配置、参数调试</li>
<li><strong>核心优势：</strong>可视化引导</li>
<li><strong>交互方式：</strong>每一步确认</li>
</ul>
</div>

</div>

## █ 极速模式使用示例

```bash
# 基础部署（默认配置）
bash <(curl...) 

# 带参数部署
bash <(curl...) --port 443 --password "Your$tr0ngP@ss"

# 专业语法
bash <(curl...) install --port 3017

# 卸载指令
bash <(curl...) uninstall
