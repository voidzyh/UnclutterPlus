#!/bin/bash

# UnclutterPlus 启动脚本

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 切换到项目目录
cd "$SCRIPT_DIR"

# 检查是否已经在运行
if pgrep -f "UnclutterPlus" > /dev/null; then
    echo "UnclutterPlus 已在运行中"
    exit 1
fi

# 启动应用
echo "正在启动 UnclutterPlus..."
nohup ./.build/debug/UnclutterPlus > app.log 2>&1 &

echo "UnclutterPlus 已启动！"
echo "- 移动鼠标到屏幕顶部边缘可激活窗口"
echo "- 查看菜单栏的托盘图标"
echo "- 运行 'tail -f app.log' 查看日志"