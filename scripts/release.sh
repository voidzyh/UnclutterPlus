#!/bin/bash

# UnclutterPlus Release Script
# 自动创建新版本和 GitHub Release

set -e

APP_NAME="UnclutterPlus"
CURRENT_VERSION=$(cat VERSION)

echo "🚀 UnclutterPlus Release Helper"
echo "Current version: $CURRENT_VERSION"

# 检查是否有未提交的更改
if [[ -n $(git status --porcelain) ]]; then
    echo "❌ Error: You have uncommitted changes. Please commit them first."
    exit 1
fi

# 检查是否在主分支
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" && "$CURRENT_BRANCH" != "master" ]]; then
    echo "⚠️  Warning: You are not on main/master branch (current: $CURRENT_BRANCH)"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# 询问新版本
echo ""
echo "Version formats:"
echo "  - Patch: 0.1.1 (bug fixes)"
echo "  - Minor: 0.2.0 (new features)"
echo "  - Major: 1.0.0 (breaking changes)"
echo ""
read -p "Enter new version (current: $CURRENT_VERSION): " NEW_VERSION

if [[ -z "$NEW_VERSION" ]]; then
    echo "❌ Error: Version cannot be empty"
    exit 1
fi

# 验证版本格式
if [[ ! $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Error: Invalid version format. Use semantic versioning (e.g., 1.0.0)"
    exit 1
fi

echo ""
echo "📝 Preparing release v$NEW_VERSION..."

# 更新版本文件
echo "$NEW_VERSION" > VERSION

# 更新 Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "Sources/$APP_NAME/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_VERSION" "Sources/$APP_NAME/Resources/Info.plist"

# 更新 CHANGELOG.md
if [[ -f "CHANGELOG.md" ]]; then
    # 将 [Unreleased] 改为新版本，并添加新的 [Unreleased] 部分
    TODAY=$(date +%Y-%m-%d)
    sed -i '' "s/## \[Unreleased\]/## [$NEW_VERSION] - $TODAY/" CHANGELOG.md
    
    # 在文件开头的 ## [Unreleased] 后插入新的 Unreleased 部分
    sed -i '' "/## \[$NEW_VERSION\] - $TODAY/i\\
## [Unreleased]\\
\\
### Added\\
\\
### Changed\\
\\
### Fixed\\
\\
" CHANGELOG.md
    
    echo "✅ Updated CHANGELOG.md"
fi

# 提交更改
git add VERSION "Sources/$APP_NAME/Resources/Info.plist"
if [[ -f "CHANGELOG.md" ]]; then
    git add CHANGELOG.md
fi

git commit -m "Release v$NEW_VERSION

- Bump version to $NEW_VERSION
- Update CHANGELOG.md"

# 创建标签
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

echo "✅ Created release commit and tag v$NEW_VERSION"

# 询问是否推送
echo ""
read -p "Push to remote repository? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push origin
    git push origin "v$NEW_VERSION"
    echo "✅ Pushed to remote repository"
    echo ""
    echo "🎉 Release v$NEW_VERSION created successfully!"
    echo ""
    echo "GitHub Actions will automatically:"
    echo "  - Build the application"
    echo "  - Create DMG package"
    echo "  - Create GitHub Release"
    echo "  - Upload release assets"
    echo ""
    echo "Check the Actions tab in your GitHub repository for build status."
else
    echo "📦 Release prepared locally. Run the following commands when ready:"
    echo "  git push origin"
    echo "  git push origin v$NEW_VERSION"
fi