#!/bin/bash

# UnclutterPlus 启动脚本
# 用于简化和标准化 UnclutterPlus 应用的启动流程

echo "🚀 启动 UnclutterPlus v2.0.0..."

# 检查是否已有进程运行
if pgrep -f "UnclutterPlus" > /dev/null; then
    echo "⚠️  检测到已有 UnclutterPlus 进程运行，正在终止..."
    pkill -f UnclutterPlus
    sleep 2
fi

# 构建应用（如果需要）
if [ ! -f ".build/debug/UnclutterPlus" ]; then
    echo "📦 构建应用..."
    swift build
    if [ $? -ne 0 ]; then
        echo "❌ 构建失败！"
        exit 1
    fi
fi

# 启动应用
echo "✅ 启动应用..."
./.build/debug/UnclutterPlus &

# 等待启动并检查状态
sleep 3
if pgrep -f "UnclutterPlus" > /dev/null; then
    echo "🎉 UnclutterPlus 启动成功！"
    echo "💡 如果界面未显示，请检查 Dock 或使用 Command+Tab 切换应用"
else
    echo "❌ 应用启动失败！"
    exit 1
fi