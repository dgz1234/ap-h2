#!/bin/sh
# █ Alpine WARP 终极稳定版 █
# 网络波动防护 | 智能重试 | 2024-07-20

# >>>>> 全局配置 <<<<<
readonly CONF_FILE="/etc/wireguard/wgcf-profile.conf"
readonly ACCOUNT_FILE="/etc/wireguard/accounts/wgcf-account.toml"
readonly WARP_TEST_IP="2606:4700:d0::a29f:c001"
readonly API_TIMEOUT=10  # 关键操作超时(秒)

# >>>>> 工具函数 <<<<<
# 带超时的命令执行
safe_run() {
    timeout "$API_TIMEOUT" "$@" >/dev/null 2>&1
    case $? in
        0) return 0 ;;
        124|137) return 1 ;;  # timeout
        *) return 1 ;;
    esac
}

# >>>>> 清理函数 <<<<<
cleanup() {
    wg-quick down wgcf-profile 2>/dev/null || true
    rm -f /tmp/wgcf-*.tmp 2>/dev/null
}
trap cleanup EXIT TERM INT

# ███ 1. 增强版账户诊断 ███
diagnose_account() {
    # 级别1: 文件存在性
    [ -f "$ACCOUNT_FILE" ] || return 1
    
    # 级别2: 私钥有效性
    grep -q "private_key" "$ACCOUNT_FILE" || return 1
    
    # 级别3: API连通性 (带网络状态检测)
    status_output=$(safe_run wgcf status && wgcf status)
    if [ $? -ne 0 ]; then
        if ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; then
            return 2  # API服务异常
        else
            return 3  # 完全断网
        fi
    fi

    # 级别4: 账户类型
    case $(echo "$status_output" | awk -F': ' '/Account type:/ {print $2}') in
        "Free"|"Team"|"Premium") return 0 ;;
        *) return 1 ;;
    esac
}

# ███ 2. 抗波动注册流程 ███
register_warp() {
    # 清理残留文件
    rm -f "$ACCOUNT_FILE" "$CONF_FILE" 2>/dev/null

    # 指数退避重试
    for attempt in 1 2 3; do
        if safe_run wgcf register --accept-tos && \
           safe_run wgcf generate && \
           [ -s "$CONF_FILE" ]; then
            [ -f "$CONF_FILE" ] && chmod 600 "$CONF_FILE"
            return 0
        fi
        sleep $((attempt * 5))
    done
    return 1
}

# ███ 3. 稳健隧道控制 ███
start_tunnel() {
    # 清理残留接口
    ip link delete dev wgcf-profile 2>/dev/null || true

    # 启动隧道 (带重试)
    for _ in 1 2 3; do
        if wg-quick up "$CONF_FILE" 2>/dev/null; then
            # 验证接口
            if ip link show dev wgcf-profile >/dev/null 2>&1; then
                # 隔离IPv4
                ip -4 route delete default dev wgcf-profile 2>/dev/null || true

                # 测试IPv6 (允许少量丢包)
                if ping -6 -c2 -W5 "$WARP_TEST_IP" >/dev/null 2>&1; then
                    return 0
                fi
            fi
        fi
        sleep 3
    done
    return 1
}

# ███ 主流程 ███
case $(diagnose_account) in
    0) ;;  # 账户正常
    1) 
        if ! register_warp; then
            exit 1
        fi
        ;;
    2|3) 
        if [ ! -f "$CONF_FILE" ]; then
            exit 1
        fi
        ;;
esac

if [ -f "$CONF_FILE" ]; then
    if start_tunnel; then
        exit 0
    else
        exit 1
    fi
else
    exit 1
fi
