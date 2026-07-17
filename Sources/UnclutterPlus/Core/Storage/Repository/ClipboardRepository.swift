import Foundation
import Combine
import SwiftUI

/// 剪贴板数据仓库
@MainActor
final class ClipboardRepository: ObservableObject {
    // MARK: - Published Properties

    /// 所有剪贴板项目索引
    @Published private(set) var clipboardIndexes: [ClipboardIndex] = []

    /// 搜索文本
    @Published var searchText: String = ""

    /// 是否只显示收藏
    @Published var showPinnedOnly: Bool = false

    // MARK: - Private Properties

    private let storage: any UnifiedStorageProtocol<ClipboardItem, ClipboardIndex>
    private let config = StorageConfiguration.default
    private var cancellables = Set<AnyCancellable>()

    // 缓存完整剪贴板内容（避免重复加载）
    private var itemCache: [UUID: ClipboardItem] = [:]

    /// 初始索引加载任务（变更操作需等待其完成，避免竞态覆盖）
    private var initialLoadTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// 过滤后的剪贴板项目
    var filteredIndexes: [ClipboardIndex] {
        var filtered = clipboardIndexes

        // 搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { index in
                index.preview.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 收藏过滤
        if showPinnedOnly {
            filtered = filtered.filter { $0.isPinned }
        }

        // 按时间排序（最新的在前）
        filtered.sort { $0.timestamp > $1.timestamp }

        return filtered
    }

    /// 所有项目数量
    var totalCount: Int {
        clipboardIndexes.count
    }

    /// 收藏项目数量
    var pinnedCount: Int {
        clipboardIndexes.filter { $0.isPinned }.count
    }

    // MARK: - Initialization

    /// 初始化剪贴板仓库
    /// - Parameter storage: 可选的存储实现（用于测试），默认为生产环境存储
    init(storage: (any UnifiedStorageProtocol<ClipboardItem, ClipboardIndex>)? = nil) {
        if let storage = storage {
            self.storage = storage
        } else {
            self.storage = StorageFactory.createClipboardStorage()
        }
        
        setupBindings()

        // 使用Task确保数据加载完成后再继续
        initialLoadTask = Task {
            await loadIndexes()
            logger.info("剪贴板数据加载完成，共 \(self.clipboardIndexes.count) 项", category: "Storage")
        }
    }

    /// 等待初始索引加载完成（变更操作前调用，避免与初始加载竞态）
    private func awaitInitialLoad() async {
        await initialLoadTask?.value
    }

    private func setupBindings() {
        // 监听搜索和过滤变化
        Publishers.CombineLatest($searchText, $showPinnedOnly)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// 加载所有剪贴板索引
    func loadIndexes() async {
        do {
            let indexes = try await storage.getAllIndexes(limit: nil, offset: nil)
            await MainActor.run {
                self.clipboardIndexes = indexes
            }
        } catch {
            logger.error("加载剪贴板索引失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 获取完整剪贴板项目
    func getItem(id: UUID) async -> ClipboardItem? {
        // 检查缓存
        if let cached = itemCache[id] {
            return cached
        }

        // 从存储加载
        do {
            if let item = try await storage.read(id: id) {
                itemCache[id] = item
                return item
            }
        } catch {
            logger.error("加载剪贴板项目失败 \(id.uuidString.prefix(8)): \(error.localizedDescription)", category: "Storage")
        }

        return nil
    }

    /// 添加新的剪贴板项目
    func addItem(_ item: ClipboardItem) async {
        await awaitInitialLoad()
        do {
            // 保存到存储
            try await storage.create([item])

            // 创建索引
            let index = ClipboardIndex(from: item)

            // 更新内存索引
            await MainActor.run {
                self.clipboardIndexes.insert(index, at: 0)
                self.itemCache[item.id] = item
            }
        } catch {
            logger.error("添加剪贴板项目失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 删除剪贴板项目
    func deleteItem(_ item: ClipboardItem) async {
        await awaitInitialLoad()
        do {
            // 从存储删除
            try await storage.delete(ids: [item.id])

            // 更新内存
            await MainActor.run {
                self.clipboardIndexes.removeAll { $0.id == item.id }
                self.itemCache.removeValue(forKey: item.id)
            }
        } catch {
            logger.error("删除剪贴板项目失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 批量删除项目
    func deleteItems(_ items: [ClipboardItem]) async {
        await awaitInitialLoad()
        let ids = items.map { $0.id }
        do {
            try await storage.delete(ids: ids)
            
            await MainActor.run {
                for item in items {
                    self.clipboardIndexes.removeAll { $0.id == item.id }
                    self.itemCache.removeValue(forKey: item.id)
                }
            }
        } catch {
            logger.error("批量删除剪贴板项目失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 切换收藏状态
    func togglePin(_ item: ClipboardItem) async {
        await awaitInitialLoad()
        var updatedItem = item
        updatedItem.isPinned.toggle()

        do {
            // 更新存储
            try await storage.update([updatedItem])

            // 更新索引
            if let index = clipboardIndexes.firstIndex(where: { $0.id == item.id }) {
                await MainActor.run {
                    var newIndex = self.clipboardIndexes[index]
                    newIndex = ClipboardIndex(from: updatedItem)
                    self.clipboardIndexes[index] = newIndex
                    self.itemCache[item.id] = updatedItem
                }
            }
        } catch {
            logger.error("切换收藏状态失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 更新剪贴板项目（通用）
    func updateItem(_ updatedItem: ClipboardItem) async {
        await awaitInitialLoad()
        do {
            try await storage.update([updatedItem])
            itemCache[updatedItem.id] = updatedItem
            if let index = clipboardIndexes.firstIndex(where: { $0.id == updatedItem.id }) {
                await MainActor.run {
                    self.clipboardIndexes[index] = ClipboardIndex(from: updatedItem)
                }
            }
        } catch {
            logger.error("更新剪贴板项目失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 增加使用计数
    func incrementUseCount(_ item: ClipboardItem) async {
        await awaitInitialLoad()
        var updatedItem = item
        updatedItem.useCount += 1

        do {
            // 更新存储
            try await storage.update([updatedItem])

            // 更新缓存
            itemCache[item.id] = updatedItem

            // 更新索引
            if let index = clipboardIndexes.firstIndex(where: { $0.id == item.id }) {
                await MainActor.run {
                    self.clipboardIndexes[index] = ClipboardIndex(from: updatedItem)
                }
            }
        } catch {
            logger.error("更新使用计数失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 清空所有剪贴板项目
    func clearAll() async {
        await awaitInitialLoad()
        do {
            try await storage.clear()

            await MainActor.run {
                self.clipboardIndexes.removeAll()
                self.itemCache.removeAll()
            }
        } catch {
            logger.error("清空所有项目失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 清空非收藏项目
    func clearUnpinned() async {
        await awaitInitialLoad()
        let unpinnedItems = clipboardIndexes.filter { !$0.isPinned }
        let ids = unpinnedItems.map { $0.id }

        do {
            try await storage.delete(ids: ids)

            await MainActor.run {
                for index in unpinnedItems {
                    self.clipboardIndexes.removeAll { $0.id == index.id }
                    self.itemCache.removeValue(forKey: index.id)
                }
            }
        } catch {
            logger.error("清理未收藏项目失败: \(error.localizedDescription)", category: "Storage")
        }
    }

    /// 搜索剪贴板项目
    func searchItems(query: String) async -> [ClipboardIndex] {
        do {
            return try await storage.search(query: query, limit: nil)
        } catch {
            logger.error("搜索项目失败: \(error.localizedDescription)", category: "Storage")
            return []
        }
    }
}
