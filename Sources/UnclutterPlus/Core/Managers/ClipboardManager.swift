import Foundation
import Combine
import AppKit

/// 剪贴板管理器 - 管理剪贴板项目
class ClipboardManager {
    static let shared = ClipboardManager()
    
    private let itemsSubject = CurrentValueSubject<[ClipboardItem], Never>([])
    var itemsPublisher: AnyPublisher<[ClipboardItem], Never> {
        itemsSubject.eraseToAnyPublisher()
    }
    
    private init() {}
    
    func loadItems() async {
        // 简化实现 - 返回空数组
        itemsSubject.send([])
    }
    
    func getAllItems() async throws -> [ClipboardItem] {
        return itemsSubject.value
    }
    
    func copyToClipboard(_ item: ClipboardItem) async throws {
        // 复制到系统剪贴板
        switch item.content {
        case .text(let text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .image(let data):
            NSPasteboard.general.clearContents()
            if NSImage(data: data) != nil {
                NSPasteboard.general.setData(data, forType: .tiff)
            }
        case .file(let url):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
        }
        
        // 更新使用计数
        await incrementUseCount(for: item)
    }
    
    func deleteItem(_ item: ClipboardItem) async throws {
        var currentItems = itemsSubject.value
        currentItems.removeAll { $0.id == item.id }
        itemsSubject.send(currentItems)
    }
    
    func clearAll() async throws {
        itemsSubject.send([])
    }
    
    func updateItem(_ updatedItem: ClipboardItem) async throws {
        var currentItems = itemsSubject.value
        if let index = currentItems.firstIndex(where: { $0.id == updatedItem.id }) {
            currentItems[index] = updatedItem
            itemsSubject.send(currentItems)
        }
    }
    
    func addItem(_ content: ClipboardContent) async throws {
        let newItem = ClipboardItem(
            id: UUID(),
            content: content,
            timestamp: Date(),
            isPinned: false,
            useCount: 0,
            sourceAppBundleID: nil,
            sourceAppName: nil,
            sourceAppIcon: nil
        )
        
        var currentItems = itemsSubject.value
        currentItems.insert(newItem, at: 0)
        itemsSubject.send(currentItems)
    }
    
    func togglePin(_ item: ClipboardItem) async throws {
        var currentItems = itemsSubject.value
        if let index = currentItems.firstIndex(where: { $0.id == item.id }) {
            currentItems[index].isPinned.toggle()
            itemsSubject.send(currentItems)
        }
    }
    
    func incrementUseCount(for item: ClipboardItem) async {
        var currentItems = itemsSubject.value
        if let index = currentItems.firstIndex(where: { $0.id == item.id }) {
            currentItems[index].useCount += 1
            itemsSubject.send(currentItems)
        }
    }
}