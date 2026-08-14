import XCTest
@testable import UnclutterPlus

/// 文件（收藏文件夹）功能流程级测试：增删 / 排序 / 过滤 / 选中 / 持久化往返
/// 通过 metadataDirectoryOverride 注入临时元数据目录，不读写真实用户目录；
/// 不调用 openFolder/showInFinder，避免触发 NSWorkspace 打开动作
final class FilesFlowTests: XCTestCase {

    var tempRoot: URL!
    var metadataDir: URL!
    var manager: FavoriteFoldersManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Given - 隔离的临时目录（元数据目录注入，避免读写真实用户目录）
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnclutterPlusFilesFlowTests")
            .appendingPathComponent(UUID().uuidString)
        metadataDir = tempRoot.appendingPathComponent("Metadata")
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        manager = FavoriteFoldersManager(metadataDirectoryOverride: metadataDir)
    }

    override func tearDownWithError() throws {
        manager = nil
        if let tempRoot = tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        tempRoot = nil
        metadataDir = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// 在临时目录中创建真实子文件夹
    private func makeSubfolder(_ name: String) throws -> URL {
        let url = try XCTUnwrap(tempRoot).appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Flow Tests

    /// 添加流程：正常添加 → 重复去重 → 非法路径拒绝 → 移除
    func testAddAndRemoveFolderFlow() throws {
        // Given - 真实存在的子文件夹
        let docsURL = try makeSubfolder("Docs")

        // When - 添加文件夹
        manager.addFolder(url: docsURL)

        // Then
        XCTAssertEqual(manager.folders.count, 1)
        XCTAssertEqual(manager.folders.first?.name, "Docs")
        XCTAssertEqual(manager.folders.first?.url, docsURL)

        // When - 重复添加同一路径
        manager.addFolder(url: docsURL)

        // Then - 被去重
        XCTAssertEqual(manager.folders.count, 1, "重复路径不应重复添加")

        // When - 添加不存在的路径
        manager.addFolder(url: tempRoot.appendingPathComponent("NotExists"))

        // Then - 被拒绝
        XCTAssertEqual(manager.folders.count, 1, "不存在的路径不应被添加")

        // When - 添加普通文件（非目录）
        let fileURL = tempRoot.appendingPathComponent("plain.txt")
        try Data("hello".utf8).write(to: fileURL)
        manager.addFolder(url: fileURL)

        // Then - 被拒绝
        XCTAssertEqual(manager.folders.count, 1, "普通文件不应被添加为文件夹")

        // When - 移除
        manager.removeFolder(try XCTUnwrap(manager.folders.first))

        // Then
        XCTAssertTrue(manager.folders.isEmpty)
    }

    /// 排序与过滤流程：名称排序 → 升降序切换 → 大小写不敏感过滤
    func testSortAndFilterFlow() throws {
        // Given - 三个名称不同的文件夹
        manager.addFolder(url: try makeSubfolder("alpha"))
        manager.addFolder(url: try makeSubfolder("Beta"))
        manager.addFolder(url: try makeSubfolder("gamma"))

        // When - 按名称排序（默认 isAscending = false，即降序）
        manager.setSortOption(.name)

        // Then
        XCTAssertEqual(manager.folders.map(\.name), ["gamma", "Beta", "alpha"], "默认应为名称降序")

        // When - 切换为升序
        manager.toggleSortOrder()

        // Then
        XCTAssertEqual(manager.folders.map(\.name), ["alpha", "Beta", "gamma"], "切换后应为名称升序")

        // When - 过滤
        let filtered = manager.getFilteredFolders(searchText: "ALPHA")

        // Then - 大小写不敏感命中
        XCTAssertEqual(filtered.map(\.name), ["alpha"], "过滤应大小写不敏感")
        XCTAssertEqual(manager.getFilteredFolders(searchText: "").count, 3, "空搜索词应返回全部")
    }

    /// 选中状态流程：选中/取消选中，移除文件夹时同步清理选中集合
    func testSelectionFlow() throws {
        // Given
        manager.addFolder(url: try makeSubfolder("One"))
        manager.addFolder(url: try makeSubfolder("Two"))
        let first = try XCTUnwrap(manager.folders.first { $0.name == "One" })
        let second = try XCTUnwrap(manager.folders.first { $0.name == "Two" })

        // When - 选中两个
        manager.toggleSelection(first)
        manager.toggleSelection(second)

        // Then
        XCTAssertEqual(manager.selectedFolders, Set([first.id, second.id]))

        // When - 再次切换取消选中
        manager.toggleSelection(first)

        // Then
        XCTAssertEqual(manager.selectedFolders, Set([second.id]))

        // When - 移除仍处于选中状态的文件夹
        manager.removeFolder(second)

        // Then - 选中集合同步清理
        XCTAssertTrue(manager.selectedFolders.isEmpty, "移除文件夹应同时清除其选中状态")
        XCTAssertTrue(manager.folders.first { $0.id == first.id } != nil, "未移除的文件夹应保留")
    }

    /// 持久化往返流程：添加 + 重命名 + 收藏 → 新实例加载 → 状态完整还原
    func testPersistenceRoundTripFlow() throws {
        // Given - 添加文件夹并修改其名称与收藏状态
        manager.addFolder(url: try makeSubfolder("Persisted"))
        let original = try XCTUnwrap(manager.folders.first)
        manager.renameFolder(original, to: "重命名后")
        manager.toggleFavorite(original)

        // When - 用同一元数据目录创建新实例（模拟应用重启）
        let reloaded = FavoriteFoldersManager(metadataDirectoryOverride: metadataDir)

        // Then - 名称、收藏状态、路径均从磁盘还原
        XCTAssertEqual(reloaded.folders.count, 1, "重启后应加载已持久化的文件夹")
        XCTAssertEqual(reloaded.folders.first?.name, "重命名后")
        XCTAssertEqual(reloaded.folders.first?.isFavorite, true)
        XCTAssertEqual(reloaded.folders.first?.url, original.url)
    }
}
