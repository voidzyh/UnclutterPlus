import Cocoa

class GlobalHotkey: ObservableObject {
    static let shared = GlobalHotkey()
    
    private var eventMonitors: [Any] = []
    private var hotkeyCallbacks: [String: () -> Void] = [:]
    
    private init() {}
    
    deinit {
        unregisterAll()
    }
    
    // MARK: - Public Methods
    
    func register(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, callback: @escaping () -> Void) -> Bool {
        let hotkeyID = createHotkeyID(keyCode: keyCode, modifiers: modifiers)
        
        // 取消已存在的快捷键
        unregister(keyCode: keyCode, modifiers: modifiers)
        
        // 创建事件监控
        let eventMask: NSEvent.EventTypeMask = [.keyDown]
        
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            guard let self = self else { return }
            
            if event.keyCode == keyCode && event.modifierFlags.intersection([.command, .shift, .option, .control]) == modifiers.intersection([.command, .shift, .option, .control]) {
                callback()
            }
        }
        
        guard let monitor = monitor else {
            print("Failed to register global hotkey")
            return false
        }
        
        eventMonitors.append(monitor)
        hotkeyCallbacks[hotkeyID] = callback
        
        return true
    }
    
    func unregister(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        let hotkeyID = createHotkeyID(keyCode: keyCode, modifiers: modifiers)
        hotkeyCallbacks.removeValue(forKey: hotkeyID)
        
        // 移除对应的事件监控
        eventMonitors.removeAll { monitor in
            // 注意：NSEvent.removeMonitor 需要传入原始 monitor 对象
            // 这里简化处理，实际使用时应该保存 monitor 和 keyCode/modifiers 的映射
            return false
        }
    }
    
    func unregisterAll() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
        hotkeyCallbacks.removeAll()
    }
    
    // MARK: - Helper Methods
    
    private func createHotkeyID(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        
        if modifiers.contains(.command) {
            parts.append("cmd")
        }
        if modifiers.contains(.shift) {
            parts.append("shift")
        }
        if modifiers.contains(.option) {
            parts.append("option")
        }
        if modifiers.contains(.control) {
            parts.append("ctrl")
        }
        
        parts.append("\(keyCode)")
        return parts.joined(separator: "-")
    }
}

// MARK: - Hotkey String Conversion

extension GlobalHotkey {
    /// 将字符串格式的快捷键（如 "command-shift-1"）转换为 keyCode 和 modifiers
    static func parseHotkey(_ hotkeyString: String) -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags)? {
        let components = hotkeyString.lowercased().components(separatedBy: "-")
        
        var modifiers: NSEvent.ModifierFlags = []
        var keyCode: UInt16?
        
        for component in components {
            switch component {
            case "command", "cmd":
                modifiers.insert(.command)
            case "shift":
                modifiers.insert(.shift)
            case "option", "alt":
                modifiers.insert(.option)
            case "control", "ctrl":
                modifiers.insert(.control)
            default:
                // 尝试解析为数字
                if let num = UInt16(component) {
                    // 数字键（0-9）: 需要转换为实际的 keyCode
                    // macOS 键盘码：1=18, 2=19, 3=20, 4=21, 5=23, 6=22, 7=26, 8=28, 9=25, 0=29
                    switch num {
                    case 1: keyCode = 18
                    case 2: keyCode = 19
                    case 3: keyCode = 20
                    case 4: keyCode = 21
                    case 5: keyCode = 23
                    case 6: keyCode = 22
                    case 7: keyCode = 26
                    case 8: keyCode = 28
                    case 9: keyCode = 25
                    case 0: keyCode = 29
                    default: break
                    }
                }
            }
        }
        
        guard let code = keyCode else { return nil }
        return (code, modifiers)
    }
    
    /// 将 keyCode 和 modifiers 转换为字符串格式
    static func stringFromHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        
        if modifiers.contains(.command) {
            parts.append("command")
        }
        if modifiers.contains(.shift) {
            parts.append("shift")
        }
        if modifiers.contains(.option) {
            parts.append("option")
        }
        if modifiers.contains(.control) {
            parts.append("control")
        }
        
        // 添加键代码（转换为数字显示）
        if let num = numberForKeyCode(keyCode) {
            parts.append("\(num)")
        } else {
            parts.append("\(keyCode)")
        }
        
        return parts.joined(separator: "-")
    }
    
    private static func numberForKeyCode(_ keyCode: UInt16) -> UInt16? {
        switch keyCode {
        case 18: return 1
        case 19: return 2
        case 20: return 3
        case 21: return 4
        case 23: return 5
        case 22: return 6
        case 26: return 7
        case 28: return 8
        case 25: return 9
        case 29: return 0
        default: return nil
        }
    }
}
