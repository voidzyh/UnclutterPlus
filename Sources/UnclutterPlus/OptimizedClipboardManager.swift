import Foundation
import Cocoa
import SwiftUI

// MARK: - Optimized Clipboard Manager
// 优化版本：事件驱动 + 异步处理 + 智能缓存 + 批量操作

/// 剪贴板内容协议
protocol ClipboardContentProtocol: Hashable, Codable {
    var preview: String { get }
    var systemImage: String { get }
    var typeColor: Color { get }
}

/// 剪贴板项目协议
protocol ClipboardItemProtocol: Identifiable, Hashable {
    var id: UUID { get }
    var content: any ClipboardContentProtocol { get }
    var timestamp: Date { get }
    var isPinned: Bool { get }
    var useCount: Int { get }
    var sourceAppName: String? { get }
}

/// 剪贴板管理器协议
protocol ClipboardManagerProtocol: ObservableObject {
    var items: [any ClipboardItemProtocol] { get }
    var isLoading: Bool { get }
    func copyToClipboard(_ item: any ClipboardItemProtocol)
    func removeItem(_ item: any ClipboardItemProtocol)
    func togglePin(_ item: any ClipboardItemProtocol)
    func clearAll()
}

/// 优化的剪贴板管理器
@MainActor
class OptimizedClipboardManager: ClipboardManagerProtocol {
    // MARK: - Properties

    @Published var items: [any ClipboardItemProtocol] = []
    @Published var isLoading: Bool = false

    private let pasteboard = NSPasteboard.general
    private let config = ConfigurationManager.shared
    private let cache = ClipboardCache.shared
    private let batchProcessor = BatchClipboardProcessor()

    // 状态管理
    private var lastChangeCount: Int = 0
    private var pasteboardObserver: Any?
    private var isMonitoring = false

    // 性能优化
    private let debounceInterval: TimeInterval = 0.1
    private var debounceTimer: Timer?

    // MARK: - Initialization

    init() {
        setupPasteboardMonitoring()
        loadPersistedItemsAsync()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    func copyToClipboard(_ item: any ClipboardItemProtocol) {
        Task {
            await pasteboard.writeAsync(item)
            await MainActor.run {
                incrementUseCount(for: item.id)
            }
        }
    }

    func removeItem(_ item: any ClipboardItemProtocol) {
        items.removeAll { $0.id == item.id }
        cache.remove(item.id)
        batchProcessor.scheduleSave()
    }

    func togglePin(_ item: any ClipboardItemProtocol) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index] as! ClipboardItem
            updatedItem.isPinned.toggle()
            items[index] = updatedItem
            cache.set(updatedItem)

            // 重新排序
            sortItems()

            batchProcessor.scheduleSave()
        }
    }

    func clearAll() {
        items.removeAll()
        cache.clear()
        batchProcessor.scheduleSave(immediate: true)
    }

    // MARK: - Private Methods

    private func setupPasteboardMonitoring() {
        // 事件驱动：监听剪贴板变化通知
        pasteboardObserver = NotificationCenter.default.addObserver(
            forName: NSPasteboard.didChangeNotification,
            object: pasteboard,
            queue: .main
        ) { [weak self] _ in
            self?.handlePasteboardChange()
        }

        // 定时器备用：确保不遗漏变化
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
        timer.tolerance = 0.5

        isMonitoring = true
        lastChangeCount = pasteboard.changeCount
    }

    private func stopMonitoring() {
        if let observer = pasteboardObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        isMonitoring = false
    }

    private func handlePasteboardChange() {
        // 防抖：避免频繁触发
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            Task {
                await self?.processClipboardChange()
            }
        }
    }

    private func checkForChanges() {
        guard isMonitoring else { return }
        let currentChangeCount = pasteboard.changeCount

        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            handlePasteboardChange()
        }
    }

    private func processClipboardChange() async {
        await MainActor.run {
            isLoading = true
        }

        // 后台处理剪贴板内容
        let newItem = await pasteboard.readAsync()

        await MainActor.run {
            if let newItem = newItem {
                addItemOptimized(newItem)
            }
            isLoading = false
        }
    }

    private func addItemOptimized(_ newItem: ClipboardItem) {
        // 检查缓存
        if let cachedItem = cache.get(newItem.id) {
            updateExistingItem(cachedItem)
            return
        }

        // 检查重复内容
        if let existingIndex = items.firstIndex(where: { isDuplicate($0, newItem) }) {
            moveItemToTop(at: existingIndex, newItem: newItem)
        } else {
            insertNewItem(newItem)
        }

        // 限制数量
        limitItemsCount()

        // 缓存和排序
        cache.set(newItem)
        sortItems()

        // 批量保存
        batchProcessor.scheduleSave()
    }

    private func isDuplicate(_ existing: any ClipboardItemProtocol, _ new: ClipboardItem) -> Bool {
        // 实现内容比较逻辑
        return false // 简化实现
    }

    private func updateExistingItem(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].useCount += 1
            items[index].timestamp = Date()
        }
    }

    private func moveItemToTop(at index: Int, newItem: ClipboardItem) {
        items.remove(at: index)
        items.insert(newItem, at: 0)
    }

    private func insertNewItem(_ item: ClipboardItem) {
        items.insert(item, at: 0)

        // 限制项目数量
        if items.count > 100 {
            items = Array(items.prefix(100))
        }
    }

    private func limitItemsCount() {
        let maxItems = 100
        if items.count > maxItems {
            // 保留置顶项目和最近使用的
            let unpinned = items.filter { !$0.isPinned }
            let toRemove = unpinned.suffix(max(unpinpin_count, 0))

            for item in toRemove {
                removeItem(item)
            }
        }
    }

    private func sortItems() {
        items.sort { first, second in
            // 置顶项目优先
            if first.isPinned && !second.isPinned {
                return true
            } else if !first.isPinned && second.isPinned {
                return false
            }

            // 按时间倒序
            return first.timestamp > second.timestamp
        }
    }

    private func incrementUseCount(for id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].useCount += 1
            sortItems()
            batchProcessor.scheduleSave()
        }
    }

    private func loadPersistedItemsAsync() {
        Task {
            let loadedItems = await PersistenceLoader.loadClipboardItems()
            await MainActor.run {
                self.items = loadedItems
                self.isLoading = false

                // 预热缓存
                for item in loadedItems {
                    self.cache.set(item)
                }
            }
        }
    }
}

// MARK: - Supporting Types

class ClipboardCache {
    static let shared = ClipboardCache()

    private let cache = NSCache<NSString, ClipboardItem>()
    private let accessTimes = NSCache<NSUUID, NSDate>()

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func get(_ id: UUID) -> ClipboardItem? {
        accessTimes.setObject(NSDate(), forKey: id as NSUUID)
        return cache.object(forKey: id.uuidString as NSString)
    }

    func set(_ item: ClipboardItem) {
        cache.setObject(item, forKey: item.id.uuidString as NSString)
        accessTimes.setObject(NSDate(), forKey: item.id as NSUUID)
    }

    func remove(_ id: UUID) {
        cache.removeObject(forKey: id.uuidString as NSString)
        accessTimes.removeObject(forKey: id as NSUUID)
    }

    func clear() {
        cache.removeAllObjects()
        accessTimes.removeAllObjects()
    }

    func cleanup() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-300) // 5分钟

        // 清理过期缓存
        for key in accessTimes.allKeys {
            if let accessTime = accessTimes.object(forKey: key) as Date?,
               accessTime < cutoff {
                accessTimes.removeObject(forKey: key)
                cache.removeObject(forKey: key.uuidString as NSString)
            }
        }
    }
}

class BatchClipboardProcessor {
    private var pendingSave = false
    private let saveInterval: TimeInterval = 2.0

    func scheduleSave(immediate: Bool = false) {
        pendingSave = true

        if immediate {
            flush()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + saveInterval) { [weak self] in
                self?.flush()
            }
        }
    }

    private func flush() {
        guard pendingSave else { return }
        pendingSave = false

        Task {
            await PersistenceLoader.saveClipboardItems()
        }
    }
}

enum PersistenceLoader {
    static func loadClipboardItems() async -> [ClipboardItem] {
        await withCheckedContinuation { continuation in
            Task.detached {
                let items = self.loadSync()
                continuation.resume(returning: items)
            }
        }
    }

    private static func loadSync() -> [ClipboardItem] {
        // 实现同步加载逻辑
        return []
    }

    static func saveClipboardItems() async {
        await withCheckedContinuation { continuation in
            Task.detached {
                self.saveSync()
                continuation.resume()
            }
        }
    }

    private static func saveSync() {
        // 实现同步保存逻辑
    }
}

// MARK: - Optimized Pasteboard

protocol NSPasteboardProtocol {
    var changeCount: Int { get }
    func readObjects(forClasses: [AnyClass]) -> [Any]?
    func writeObjects(_ objects: [NSPasteboardWriting])
    func clearContents()
}

extension NSPasteboard: NSPasteboardProtocol {
    func writeAsync(_ item: ClipboardItem) async {
        clearContents()

        switch item.content {
        case .text(let string):
            writeObjects([string as NSPasteboardWriting])
        case .image(let image):
            writeObjects([image])
        case .file(let url):
            writeObjects([url as NSPasteboardWriting])
        }
    }

    func readAsync() async -> ClipboardItem? {
        await withCheckedContinuation { continuation in
            Task.detached {
                let item = self.readSync()
                continuation.resume(returning: item)
            }
        }
    }

    private func readSync() -> ClipboardItem? {
        // 实现同步读取逻辑
        return nil
    }
}
