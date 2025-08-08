# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- 重新设计触发机制，改为基于滚轮和双指下滑手势触发，避免频繁误触发
- 简化触摸板支持，只保留双指向下滑动，提高响应速度
- 优化手势检测延迟，降低触发阈值并减少冷却时间
- 增强多屏幕布局支持，智能处理上下屏幕排列避免窗口遮挡
- 改进划出动画效果，使用自定义贝塞尔曲线和透明度变化
- 减少调试日志输出频率，提升整体性能

### Technical Details
- EdgeMouseTracker 完全重构，从简单的鼠标移动检测改为智能手势检测
- WindowManager 中的动画系统优化，支持多屏幕自适应定位
- 触发机制现在需要明确的用户意图：滚轮或双指滑动，而非简单的鼠标移动

## [0.1.0] - 2025-08-08

### Added
- 🗂️ 文件管理功能
  - 临时文件存储，支持拖拽操作
  - 智能文件图标识别
  - 右键菜单快速操作
  - 文件大小显示

- 📋 剪贴板历史功能
  - 多格式支持：文本、图片、文件
  - 智能搜索功能
  - 持久化存储
  - 一键复制回剪贴板

- 📝 增强 Markdown 笔记功能
  - 完整 Markdown 语法支持
  - 实时预览
  - 语法高亮
  - 自动保存
  - Markdown 工具栏

- 🖥️ 系统集成
  - 屏幕边缘触发（原始版本）
  - 菜单栏集成
  - 流畅动画效果
  - 窗口管理

### Technical
- 基于 SwiftUI 构建
- Swift Package Manager 项目结构
- 支持 macOS 14.0+
- 本地数据存储，无网络通信