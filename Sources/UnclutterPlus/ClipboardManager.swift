import Foundation
import Cocoa
import SwiftUI

enum ClipboardContent: Hashable {
    case text(String)
    case image(NSImage)
    case file(URL)
}

struct ClipboardItem: Identifiable, Hashable {
    let id = UUID()
    let content: ClipboardContent
    let timestamp: Date
    
    var systemImage: String {
        switch content {
        case .text:
            return "doc.plaintext"
        case .image:
            return "photo"
        case .file:
            return "doc"
        }
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class ClipboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []
    
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxItems = 100
    private let pasteboard = NSPasteboard.general
    
    init() {
        startMonitoring()
        loadPersistedItems()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        lastChangeCount = pasteboard.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForClipboardChanges()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForClipboardChanges() {
        let currentChangeCount = pasteboard.changeCount
        
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            captureClipboardContent()
        }
    }
    
    private func captureClipboardContent() {
        // 优先级：文件 > 图片 > 文本
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first {
            addItem(.file(url))
        } else if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            addItem(.image(image))
        } else if let string = pasteboard.string(forType: .string), !string.isEmpty {
            addItem(.text(string))
        }
    }
    
    private func addItem(_ content: ClipboardContent) {
        // 检查是否已存在相同内容
        let isDuplicate = items.contains { item in
            switch (item.content, content) {
            case (.text(let existing), .text(let new)):
                return existing == new
            case (.file(let existing), .file(let new)):
                return existing == new
            case (.image(let existing), .image(let new)):
                return existing.tiffRepresentation == new.tiffRepresentation
            default:
                return false
            }
        }
        
        if !isDuplicate {
            let item = ClipboardItem(content: content, timestamp: Date())
            items.insert(item, at: 0)
            
            // 限制项目数量
            if items.count > maxItems {
                items = Array(items.prefix(maxItems))
            }
            
            persistItems()
        }
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        
        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let image):
            pasteboard.writeObjects([image])
        case .file(let url):
            pasteboard.writeObjects([url as NSURL])
        }
        
        // 更新变更计数以避免重复捕获
        lastChangeCount = pasteboard.changeCount
    }
    
    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persistItems()
    }
    
    func clearAll() {
        items.removeAll()
        persistItems()
    }
    
    private func persistItems() {
        // 只持久化文本内容（图片和文件太大）
        let textItems = items.compactMap { item -> [String: Any]? in
            switch item.content {
            case .text(let text):
                return [
                    "type": "text",
                    "content": text,
                    "timestamp": item.timestamp.timeIntervalSince1970
                ]
            default:
                return nil
            }
        }
        
        UserDefaults.standard.set(textItems, forKey: "ClipboardHistory")
    }
    
    private func loadPersistedItems() {
        guard let data = UserDefaults.standard.array(forKey: "ClipboardHistory") as? [[String: Any]] else {
            return
        }
        
        let loadedItems = data.compactMap { dict -> ClipboardItem? in
            guard let type = dict["type"] as? String,
                  let content = dict["content"] as? String,
                  let timestamp = dict["timestamp"] as? TimeInterval,
                  type == "text" else {
                return nil
            }
            
            return ClipboardItem(
                content: .text(content),
                timestamp: Date(timeIntervalSince1970: timestamp)
            )
        }
        
        items = loadedItems.sorted { $0.timestamp > $1.timestamp }
    }
}