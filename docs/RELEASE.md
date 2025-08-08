# Release Guide

本文档说明如何为 UnclutterPlus 项目创建新版本和发布。

## 发布流程概述

UnclutterPlus 使用自动化的发布流程，通过 GitHub Actions 自动构建和发布：

1. **本地准备** → 2. **创建标签** → 3. **自动构建** → 4. **GitHub Release**

## 快速发布

### 使用发布脚本（推荐）

```bash
# 运行交互式发布脚本
./scripts/release.sh
```

脚本会自动：
- 检查工作目录状态
- 提示输入新版本号
- 更新版本文件和 Info.plist
- 更新 CHANGELOG.md
- 创建提交和标签
- 推送到远程仓库

### 手动发布

1. **更新版本号**
```bash
echo "1.0.0" > VERSION
```

2. **更新 Info.plist**
```bash
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0.0" Sources/UnclutterPlus/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 1.0.0" Sources/UnclutterPlus/Info.plist
```

3. **更新 CHANGELOG.md**
   - 将 `[Unreleased]` 部分改为新版本
   - 添加发布日期
   - 创建新的 `[Unreleased]` 部分

4. **提交和标签**
```bash
git add VERSION Sources/UnclutterPlus/Info.plist CHANGELOG.md
git commit -m "Release v1.0.0"
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin main
git push origin v1.0.0
```

## 自动化构建

当推送标签到 GitHub 后，GitHub Actions 会自动：

### 构建流程
1. **环境准备** - 设置 macOS 14 + Xcode 15.4
2. **代码检出** - 获取完整源代码
3. **Swift 构建** - 构建 release 版本（支持 ARM64 + Intel）
4. **应用打包** - 创建 .app 包
5. **DMG 制作** - 创建安装用 DMG 文件
6. **归档创建** - 生成源码和二进制 ZIP 包

### 发布产物
每个 Release 包含以下文件：
- `UnclutterPlus-vX.X.X.dmg` - 安装包（推荐下载）
- `UnclutterPlus-vX.X.X-source.zip` - 源代码包
- `UnclutterPlus-vX.X.X-macos.zip` - 应用包（不包含安装器）

## 版本命名规范

遵循 [语义化版本](https://semver.org/lang/zh-CN/) 规范：

- **MAJOR.MINOR.PATCH** (例：1.0.0)
- **主版本号**：不兼容的 API 修改
- **次版本号**：向下兼容的功能性新增
- **修订版本号**：向下兼容的问题修正

### 示例
- `0.1.0` - 初始开发版本
- `0.2.0` - 新功能添加
- `0.2.1` - Bug 修复
- `1.0.0` - 首个稳定版本

## 预发布和测试

### 本地构建测试
```bash
# 本地构建测试
./scripts/build.sh

# 检查生成的应用包
open release/UnclutterPlus.app
```

### GitHub Actions 手动触发
可以在 GitHub Actions 页面手动触发构建：
1. 访问 Actions 标签
2. 选择 "Release" 工作流
3. 点击 "Run workflow"
4. 输入版本号（如 v1.0.0）

## 发布检查清单

发布前确认：

- [ ] 所有功能正常工作
- [ ] 测试用例通过
- [ ] 文档已更新
- [ ] CHANGELOG.md 已更新
- [ ] 版本号符合语义化版本规范
- [ ] Info.plist 版本信息正确
- [ ] 本地构建成功

发布后检查：

- [ ] GitHub Actions 构建成功
- [ ] Release 页面显示正确
- [ ] DMG 文件可以正常下载
- [ ] 应用可以正常安装和运行
- [ ] 所有发布产物完整

## 故障排除

### 构建失败
- 检查 GitHub Actions 日志
- 确认 Xcode 版本兼容性
- 验证代码签名配置（如果启用）

### DMG 创建失败
- 检查磁盘空间
- 验证应用包结构
- 确认权限设置

### 版本冲突
- 确保标签名唯一
- 检查版本号格式
- 验证 Info.plist 更新

## 代码签名（可选）

如果需要分发签名版本：

1. 添加开发者证书到 GitHub Secrets
2. 更新 `.github/workflows/release.yml` 中的代码签名部分
3. 启用公证（Notarization）流程

更多信息请参考 Apple 开发者文档。