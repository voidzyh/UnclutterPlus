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

    private let storage: ClipboardStorageAdapter
    private let config = StorageConfiguration.default
    private var cancellables = Set<AnyCancellable>()

    // 缓存完整剪贴板内容（避免重复加载）
    private var itemCache: [UUID: ClipboardItem] = [:]

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

    init() {
        // 创建剪贴板存储适配器
        let shardedStorage = ShardedStorage<ClipboardItem>(
            baseURL: config.baseURL.appendingPathComponent("Clipboard"),
            strategy: .byMonth // 按月分片，适合时间序列数据
        )
        self.storage = ClipboardStorageAdapter(shardedStorage: shardedStorage)

        setupBindings()

        Task {
            await loadIndexes()
        }
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
            let indexes = try await storage.getAllIndexes()
            await MainActor.run {
                self.clipboardIndexes = indexes
            }
        } catch {
            print("❌ Failed to load clipboard indexes: \(error)")
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
            print("❌ Failed to load clipboard item \(id): \(error)")
        }

        return nil
    }

    /// 添加新的剪贴板项目
    func addItem(_ item: ClipboardItem) async {
        do {
            // 保存到存储
            try await storage.create(item)

            // 创建索引
            let index = ClipboardIndex(from: item)

            // 更新内存索引
            await MainActor.run {
                self.clipboardIndexes.insert(index, at: 0)
                self.itemCache[item.id] = item
            }
        } catch {
            print("❌ Failed to add clipboard item: \(error)")
        }
    }

    /// 删除剪贴板项目
    func deleteItem(_ item: ClipboardItem) async {
        do {
            // 从存储删除
            try await storage.delete(id: item.id)

            // 更新内存
            await MainActor.run {
                self.clipboardIndexes.removeAll { $0.id == item.id }
                self.itemCache.removeValue(forKey: item.id)
            }
        } catch {
            print("❌ Failed to delete clipboard item: \(error)")
        }
    }

    /// 批量删除项目
    func deleteItems(_ items: [ClipboardItem]) async {
        for item in items {
            await deleteItem(item)
        }
    }

    /// 切换收藏状态
    func togglePin(_ item: ClipboardItem) async {
        var updatedItem = item
        updatedItem.isPinned.toggle()

        do {
            // 更新存储
            try await storage.update(updatedItem)

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
            print("❌ Failed to toggle pin: \(error)")
        }
    }

    /// 增加使用计数
    func incrementUseCount(_ item: ClipboardItem) async {
        var updatedItem = item
        updatedItem.useCount += 1

        do {
            // 更新存储
            try await storage.update(updatedItem)

            // 更新缓存
            itemCache[item.id] = updatedItem

            // 更新索引
            if let index = clipboardIndexes.firstIndex(where: { $0.id == item.id }) {
                await MainActor.run {
                    self.clipboardIndexes[index] = ClipboardIndex(from: updatedItem)
                }
            }
        } catch {
            print("❌ Failed to update use count: \(error)")
        }
    }

    /// 清空所有剪贴板项目
    func clearAll() async {
        do {
            try await storage.clear()

            await MainActor.run {
                self.clipboardIndexes.removeAll()
                self.itemCache.removeAll()
            }
        } catch {
            print("❌ Failed to clear all items: \(error)")
        }
    }

    /// 清空非收藏项目
    func clearUnpinned() async {
        let unpinnedItems = clipboardIndexes.filter { !$0.isPinned }

        for index in unpinnedItems {
            do {
                try await storage.delete(id: index.id)

                await MainActor.run {
                    self.clipboardIndexes.removeAll { $0.id == index.id }
                    self.itemCache.removeValue(forKey: index.id)
                }
            } catch {
                print("❌ Failed to delete unpinned item \(index.id): \(error)")
            }
        }
    }

    /// 搜索剪贴板项目
    func searchItems(query: String) async -> [ClipboardIndex] {
        do {
            return try await storage.search(query: query)
        } catch {
            print("❌ Failed to search items: \(error)")
            return []
        }
    }
}