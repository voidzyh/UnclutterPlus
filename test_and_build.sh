#!/bin/bash

echo "🔨 构建UnclutterPlus..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ 构建成功！"
    echo "🚀 启动应用..."
    ./start.sh
    echo "📝 请运行以下命令测试剪贴板持久化："
    echo "   swift test_clipboard_persistence.swift"
else
    echo "❌ 构建失败！"
    exit 1
fi
