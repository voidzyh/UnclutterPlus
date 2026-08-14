#!/bin/bash

# UnclutterPlus Build Script
# 用于本地构建和打包应用

set -e  # 遇到错误立即退出

APP_NAME="UnclutterPlus"
VERSION=$(cat VERSION)
BUILD_DIR=".build"
RELEASE_DIR="release"

echo "🏗️  Building $APP_NAME v$VERSION"

# 清理之前的构建
if [ -d "$BUILD_DIR" ]; then
    echo "🧹 Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

if [ -d "$RELEASE_DIR" ]; then
    echo "🧹 Cleaning previous release..."
    rm -rf "$RELEASE_DIR"
fi

# 构建发布版本
echo "🔨 Building release binary..."
swift build -c release --arch arm64 --arch x86_64

# 创建发布目录
mkdir -p "$RELEASE_DIR"

# 创建应用包
echo "📦 Creating app bundle..."
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 复制可执行文件
# 检查通用二进制构建路径
if [ -f "$BUILD_DIR/apple/Products/Release/$APP_NAME" ]; then
    cp "$BUILD_DIR/apple/Products/Release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
elif [ -f "$BUILD_DIR/release/$APP_NAME" ]; then
    cp "$BUILD_DIR/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
else
    echo "❌ Error: Cannot find executable file"
    exit 1
fi

# 复制 Info.plist
cp "Sources/$APP_NAME/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# 复制 SwiftPM 资源 bundle（含全部 lproj 本地化资源，LocalizationManager 依赖 Bundle.module）
# macOS 上 bundle 后缀为 .bundle（Linux 为 .resources），多架构构建位于 apple/Products/Release
RESOURCE_BUNDLE_FOUND=""
for candidate in \
    "$BUILD_DIR/apple/Products/Release/${APP_NAME}_${APP_NAME}.bundle" \
    "$BUILD_DIR/release/${APP_NAME}_${APP_NAME}.bundle" \
    "$BUILD_DIR/apple/Products/Release/${APP_NAME}_${APP_NAME}.resources" \
    "$BUILD_DIR/release/${APP_NAME}_${APP_NAME}.resources"; do
    if [ -d "$candidate" ]; then
        RESOURCE_BUNDLE_FOUND="$candidate"
        break
    fi
done
if [ -n "$RESOURCE_BUNDLE_FOUND" ]; then
    cp -R "$RESOURCE_BUNDLE_FOUND" "$APP_BUNDLE/Contents/Resources/"
    echo "✅ SwiftPM resource bundle included ($(basename "$RESOURCE_BUNDLE_FOUND"))"
else
    echo "⚠️  Warning: SwiftPM resource bundle not found, localization will not work"
fi

# 复制图标文件
if [ -f "Sources/$APP_NAME/Resources/$APP_NAME.icns" ]; then
    cp "Sources/$APP_NAME/Resources/$APP_NAME.icns" "$APP_BUNDLE/Contents/Resources/"
    echo "✅ App icon included"
else
    echo "⚠️  Warning: No app icon found"
fi

# 设置可执行权限
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "✅ App bundle created at: $APP_BUNDLE"

# 创建 DMG（如果是 macOS）
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "💿 Creating DMG..."
    
    DMG_NAME="$APP_NAME-v$VERSION"
    
    # 创建临时 DMG 目录
    mkdir -p dmg-temp
    cp -R "$APP_BUNDLE" dmg-temp/
    
    # 创建 Applications 文件夹的符号链接
    ln -s /Applications dmg-temp/Applications
    
    # 创建 DMG
    hdiutil create -size 200m -fs HFS+ -volname "$DMG_NAME" temp.dmg >/dev/null
    hdiutil attach temp.dmg -mountpoint "/Volumes/$DMG_NAME" >/dev/null
    
    # 复制内容到 DMG
    cp -R dmg-temp/* "/Volumes/$DMG_NAME/"
    
    # 卸载临时 DMG
    hdiutil detach "/Volumes/$DMG_NAME" >/dev/null
    
    # 创建最终的压缩 DMG
    hdiutil convert temp.dmg -format UDZO -o "$RELEASE_DIR/$DMG_NAME.dmg" >/dev/null
    
    # 清理临时文件
    rm temp.dmg
    rm -rf dmg-temp
    
    echo "✅ DMG created at: $RELEASE_DIR/$DMG_NAME.dmg"
fi

# 创建 ZIP 归档
echo "📦 Creating ZIP archive..."
cd "$RELEASE_DIR"
zip -r "$APP_NAME-v$VERSION-macos.zip" "$APP_NAME.app" >/dev/null
cd ..

echo "🎉 Build completed successfully!"
echo ""
echo "📁 Release files:"
ls -la "$RELEASE_DIR/"

echo ""
echo "🚀 Ready for distribution!"