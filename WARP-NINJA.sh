#!/bin/sh
# █ Alpine WARP 智能账户版 █
# 精准识别账户状态 | 2024-07-20

# >>>>> 用户配置区 <<<<<
SSH_IP="2001:41d0:303:3e79:be24:11ff:fe7c:6302"
WARP_LOCK="2606:4700:d0::a29f:c001"

# ███ 五级账户诊断 ███
diagnose_account() {
    echo "🩺 开始账户诊断..."
    
    # 级别1：检查账户文件存在性
    if [ ! -f "/etc/wireguard/accounts/wgcf-account.toml" ]; then
        echo "❌ 级别1/5：账户文件不存在"
        return 1
    fi
    
    # 级别2：验证文件完整性
    if ! grep -q "account_id" "/etc/wireguard/accounts/wgcf-account.toml"; then
        echo "❌ 级别2/5：账户文件损坏"
        return 1
    fi
    
    # 级别3：检查API连通性
    if ! wgcf status &>/dev/null; then
        echo "⚠️ 级别3/5：账户状态不可查（可能网络问题）"
        return 2
    fi
    
    # 级别4：验证账户类型
    case $(wgcf status | awk '/Account type:/ {print $3}') in
        "free"|"paid")
            echo "✅ 级别5/5：账户有效（$(wgcf status | grep 'Account type')）"
            return 0
            ;;
        *)
            echo "❌ 级别4/5：账户类型异常"
            return 1
            ;;
    esac
}

# ███ 智能注册决策 ███
handle_invalid_account() {
    local diagnosis=$1
    
    case $diagnosis in
        # 文件不存在或损坏时强制注册
        1)
            echo "🚨 账户不可恢复，执行安全注册..."
            rm -f "/etc/wireguard/accounts/wgcf-account.toml"
            register_warp
            ;;
        # 网络问题时的优雅处理
        2)
            echo "🔄 检测到网络问题，尝试使用现有配置..."
            [ -f "wgcf-profile.conf" ] && return 0
            echo "⚠️ 无可用配置，等待用户干预"
            exit 1
            ;;
    esac
}

# ███ 安全注册流程 ███
register_warp() {
    echo "📝 开始新账户注册流程..."
    for i in 1 2 3; do
        if WG_DEBUG=1 wgcf register --accept-tos; then
            echo "🎉 账户注册成功"
            return 0
        fi
        echo "⚠️ 第$i次尝试失败，等待20秒..."
        sleep 20
    done
    exit 1
}

# ███ 主流程 ███
set -e
diagnose_account || handle_invalid_account $?
generate_config
start_tunnel