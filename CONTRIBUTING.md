# Contributing to UnclutterPlus

感谢您对 UnclutterPlus 项目的关注！我们欢迎各种形式的贡献。

## 如何贡献

### 报告 Bug
1. 检查 [Issues](https://github.com/voidzyh/UnclutterPlus/issues) 确认问题未被报告
2. 创建新的 Issue，包含：
   - 详细的问题描述
   - 重现步骤
   - 预期行为 vs 实际行为
   - 系统环境信息（macOS 版本等）
   - 截图（如适用）

### 功能请求
1. 在 Issues 中描述新功能
2. 说明功能的用途和价值
3. 提供可能的实现思路

### 代码贡献
1. Fork 项目
2. 创建功能分支：`git checkout -b feature/amazing-feature`
3. 提交更改：`git commit -m 'Add amazing feature'`
4. 推送分支：`git push origin feature/amazing-feature`
5. 创建 Pull Request

## 开发环境设置

### 要求
- macOS 12.0+
- Xcode 14.0+
- Swift 5.7+

### 设置步骤
```bash
git clone https://github.com/voidzyh/UnclutterPlus.git
cd UnclutterPlus
open Package.swift
```

### 构建和测试
```bash
# 构建项目
swift build

# 运行测试
swift test

# 创建发布版本
./scripts/build.sh
```

## 发布流程

### 创建新版本
使用发布脚本创建新版本：
```bash
./scripts/release.sh
```

或手动创建：
1. 更新 `VERSION` 文件
2. 更新 `CHANGELOG.md`
3. 创建标签并推送

详细说明请参考 [Release Guide](docs/RELEASE.md)。

## 代码规范

- 使用 Swift 官方代码风格
- 添加适当的注释
- 确保代码通过所有测试
- 遵循现有的架构模式

## Pull Request 指南

- 确保 PR 描述清晰
- 关联相关的 Issue
- 包含测试（如适用）
- 更新文档（如需要）

## 行为准则

请遵循友善、包容的交流原则，尊重所有贡献者。