#!/usr/bin/env swift

import Foundation
import AppKit

// 测试剪贴板持久化功能的脚本
// 使用方法：在终端中运行 `swift test_clipboard_persistence.swift`

func testClipboardPersistence() {
    print("🧪 开始测试剪贴板持久化功能...")
    
    // 1. 创建测试数据
    let testText = "测试剪贴板持久化 - \(Date())"
    let pasteboard = NSPasteboard.general
    
    // 2. 写入测试数据到剪贴板
    pasteboard.clearContents()
    pasteboard.setString(testText, forType: .string)
    print("✅ 已写入测试数据到剪贴板: \(testText)")
    
    // 3. 等待一段时间让应用处理
    print("⏳ 等待3秒让应用处理剪贴板变化...")
    Thread.sleep(forTimeInterval: 3.0)
    
    // 4. 检查剪贴板数据是否被保存
    print("📋 检查剪贴板数据是否被保存...")
    
    // 5. 模拟应用重启 - 清除剪贴板内容
    pasteboard.clearContents()
    print("🗑️ 已清除剪贴板内容，模拟应用重启")
    
    // 6. 等待一段时间
    print("⏳ 等待2秒...")
    Thread.sleep(forTimeInterval: 2.0)
    
    // 7. 提示用户检查应用中的剪贴板历史
    print("👀 请检查UnclutterPlus应用中的剪贴板历史，应该能看到之前保存的内容")
    print("📝 测试内容: \(testText)")
    print("✅ 测试完成！")
}

// 运行测试
testClipboardPersistence()
