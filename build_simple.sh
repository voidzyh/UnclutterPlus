#!/bin/bash

# UnclutterPlus 简化构建脚本
# 这个脚本会尝试构建一个最小可工作的版本

echo "🚀 开始构建 UnclutterPlus 简化版本..."

# 清理之前的构建
echo "📦 清理构建缓存..."
swift package clean

# 尝试构建
echo "🔨 开始构建..."
swift build --configuration debug 2>&1 | tee build.log

# 检查构建结果
if [ $? -eq 0 ]; then
    echo "✅ 构建成功！"
    echo "📍 可执行文件位置: .build/debug/UnclutterPlus"
else
    echo "❌ 构建失败"
    echo "📋 错误日志已保存到 build.log"
    echo "🔍 主要错误类型："
    grep -E "error:" build.log | head -10
fi

echo "🎯 构建完成"