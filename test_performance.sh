#!/bin/bash

# go-wrk 性能测试脚本
# 用于测试优化前后的性能差异

set -e

echo "=== go-wrk 性能测试 ==="
echo "测试时间: $(date)"
echo ""

# 测试参数
CONCURRENT=1000
DURATION=10
TARGET_URL="http://localhost:8080/plaintext"

# 检查是否有目标服务器在运行
echo "检查目标服务器..."
if ! curl -s --head $TARGET_URL > /dev/null 2>&1; then
    echo "警告: 目标服务器 $TARGET_URL 不可达"
    echo "请先启动测试服务器，例如:"
    echo "  docker run -d -p 8080:8080 --name test-server some-web-server"
    echo "或使用现有服务器"
    read -p "是否继续测试? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 测试函数
run_test() {
    local test_name=$1
    local binary_path=$2
    
    echo ""
    echo "=== 测试: $test_name ==="
    echo "并发数: $CONCURRENT"
    echo "持续时间: ${DURATION}秒"
    echo "目标URL: $TARGET_URL"
    echo ""
    
    # 运行测试
    $binary_path -c $CONCURRENT -d $DURATION $TARGET_URL || {
        echo "测试失败!"
        return 1
    }
    
    echo ""
}

# 检查是否有优化前后的二进制文件
echo "检查二进制文件..."

# 假设优化后的二进制在 /tmp/go-wrk-optimized
# 假设原始二进制在 /tmp/go-wrk-original

# 如果没有二进制文件，提示构建
if [ ! -f "/tmp/go-wrk-optimized" ] || [ ! -f "/tmp/go-wrk-original" ]; then
    echo "未找到测试二进制文件"
    echo "请先构建:"
    echo "1. 原始版本: go build -o /tmp/go-wrk-original"
    echo "2. 优化版本: 使用优化后的Dockerfile构建"
    exit 1
fi

# 运行测试
run_test "原始版本" "/tmp/go-wrk-original"
run_test "优化版本" "/tmp/go-wrk-optimized"

echo "=== 测试完成 ==="
echo ""
echo "性能对比总结:"
echo "1. 检查 Requests/sec 指标"
echo "2. 检查平均响应时间"
echo "3. 检查错误率"
echo ""
echo "优化建议:"
echo "- 如果性能提升不明显，尝试调整并发数"
echo "- 检查目标服务器是否成为瓶颈"
echo "- 考虑网络延迟影响"
