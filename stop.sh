#!/bin/bash

# UnclutterPlus 停止脚本

echo "正在停止 UnclutterPlus..."

# 查找并终止进程
if pgrep -f "UnclutterPlus" > /dev/null; then
    pkill -f UnclutterPlus
    echo "UnclutterPlus 已停止"
else
    echo "UnclutterPlus 没有在运行"
fi