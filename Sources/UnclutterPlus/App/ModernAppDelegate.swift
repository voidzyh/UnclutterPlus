import Cocoa
import SwiftUI

/// 现代化的应用委托 - 简化版本以修复构建错误
class ModernAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("ModernUnclutterPlus app launched")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("ModernUnclutterPlus app will terminate")
    }
}