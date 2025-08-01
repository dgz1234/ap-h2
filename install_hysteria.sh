#!/bin/bash
set -euo pipefail

#######################################
# 修复重点：用户/组创建逻辑
#######################################

create_service_user() {
    # 先尝试删除可能存在的旧用户（静默失败）
    deluser hysteria 2>/dev/null || true
    delgroup hysteria 2>/dev/null || true

    # 创建组（如果不存在）
    if ! grep -q "^hysteria:" /etc/group; then
        addgroup -S hysteria || {
            echo "❌ 无法创建hysteria组" >&2
            return 1
        }
    fi

    # 创建用户并绑定到组
    adduser -S -D -H -G hysteria hysteria || {
        echo "❌ 无法创建hysteria用户" >&2
        return 1
    }

    # 最终验证
    if ! id hysteria &>/dev/null; then
        echo "⚠️ 将回退到root用户运行" >&2
        echo "hysteria" > /tmp/hysteria_user_fallback
        return 1
    fi
}

#######################################
# 主逻辑（测试用简化版）
#######################################

main() {
    echo "=== 测试用户创建 ==="
    if ! create_service_user; then
        echo "--- 用户创建失败，使用回退方案 ---"
        HYSTERIA_USER="root"
    else
        HYSTERIA_USER="hysteria"
        echo "✅ 用户创建成功"
        echo "用户信息: $(id hysteria)"
    fi

    echo "=== 测试权限设置 ==="
    mkdir -p /tmp/test_hysteria
    touch /tmp/test_hysteria/test_file
    
    if [ "$HYSTERIA_USER" != "root" ]; then
        if chown $HYSTERIA_USER:$HYSTERIA_USER /tmp/test_hysteria/test_file; then
            echo "✅ 权限设置成功"
        else
            echo "❌ 权限设置失败"
        fi
    else
        echo "⚠️ 跳过权限设置（使用root）"
    fi

    echo "=== 测试结果 ==="
    ls -ld /tmp/test_hysteria/test_file
    echo "运行用户: $HYSTERIA_USER"
    
    # 清理测试文件
    rm -rf /tmp/test_hysteria
    [ -f /tmp/hysteria_user_fallback ] && rm /tmp/hysteria_user_fallback
}

main "$@"