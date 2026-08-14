import XCTest
@testable import UnclutterPlus

/// 笔记功能流程级测试：创建 → 编辑 → 搜索 → 收藏 → 删除 全链路
/// 使用 MockNoteStorage 隔离存储层，无真实用户数据副作用
@MainActor
final class NotesFlowTests: XCTestCase {

    var notesService: NotesService!
    var mockStorage: MockNoteStorage!

    override func setUp() async throws {
        try await super.setUp()
        mockStorage = MockNoteStorage()
        notesService = NotesService(storage: mockStorage)
    }

    override func tearDown() async throws {
        notesService = nil
        mockStorage = nil
        try await super.tearDown()
    }

    // MARK: - Flow Tests

    /// 全链路：创建 → 索引出现 → 编辑 → 搜索命中 → 收藏 → 删除
    func testFullNoteLifecycleFlow() async throws {
        // Given - 创建笔记
        let created = await notesService.createNote(title: "流程笔记", content: "初始内容", tags: ["flow"])

        // Then - 创建成功且索引出现
        XCTAssertTrue(created, "笔记创建应该成功")
        XCTAssertEqual(notesService.noteIndexes.count, 1, "索引中应该出现新笔记")
        let noteID = try XCTUnwrap(notesService.noteIndexes.first?.id)

        // When - 编辑内容
        let fetchedOriginal = await notesService.getNote(id: noteID)
        let original = try XCTUnwrap(fetchedOriginal)
        let updated = await notesService.updateNote(original, content: "编辑后的内容 flow-updated")

        // Then - 更新成功且搜索命中新内容
        XCTAssertTrue(updated, "笔记更新应该成功")
        let hits = await notesService.searchNotes(query: "flow-updated")
        XCTAssertEqual(hits.map(\.id), [noteID], "搜索应命中编辑后的内容")

        // When - 取最新版本后切换收藏
        let fetchedFresh = await notesService.getNote(id: noteID)
        let freshNote = try XCTUnwrap(fetchedFresh)
        let toggled = await notesService.toggleFavorite(freshNote)

        // Then - 收藏生效且不覆盖已编辑的内容
        XCTAssertTrue(toggled, "收藏切换应该成功")
        XCTAssertEqual(notesService.noteIndexes.first { $0.id == noteID }?.isFavorited, true, "索引应反映收藏状态")
        let fetchedAfterFavorite = await notesService.getNote(id: noteID)
        let afterFavorite = try XCTUnwrap(fetchedAfterFavorite)
        XCTAssertEqual(afterFavorite.isFavorite, true)
        XCTAssertEqual(afterFavorite.content, "编辑后的内容 flow-updated", "收藏操作不应覆盖内容")

        // When - 删除
        let deleted = await notesService.deleteNote(afterFavorite)

        // Then - 索引与存储同步清空
        XCTAssertTrue(deleted, "笔记删除应该成功")
        XCTAssertTrue(notesService.noteIndexes.isEmpty, "删除后索引应为空")
        let deletedFetch = await notesService.getNote(id: noteID)
        XCTAssertNil(deletedFetch, "删除后不应再取到笔记")
        let storedCount = try await mockStorage.count()
        XCTAssertEqual(storedCount, 0, "存储层应为空")
    }

    /// 空标题 / 纯空白标题拒绝创建，拒绝后服务仍可正常使用
    func testEmptyTitleRejectedFlow() async throws {
        // Given - 空标题与纯空白标题
        let emptyResult = await notesService.createNote(title: "", content: "内容")
        let blankResult = await notesService.createNote(title: "   \n\t ", content: "内容")

        // Then - 均被拒绝且不产生任何写入
        XCTAssertFalse(emptyResult, "空标题应被拒绝")
        XCTAssertFalse(blankResult, "纯空白标题应被拒绝")
        XCTAssertTrue(notesService.noteIndexes.isEmpty, "拒绝后不应产生索引")
        let storedCount = try await mockStorage.count()
        XCTAssertEqual(storedCount, 0, "存储层不应有写入")

        // When - 拒绝后创建合法笔记（错误恢复）
        let validResult = await notesService.createNote(title: "合法标题", content: "内容")

        // Then
        XCTAssertTrue(validResult, "拒绝非法输入后合法笔记应创建成功")
        XCTAssertEqual(notesService.noteIndexes.count, 1)
    }

    /// 批量删除流程：仅目标笔记被移除，其余保留
    func testBatchDeleteFlow() async throws {
        // Given - 创建三条笔记
        for i in 1...3 {
            let result = await notesService.createNote(title: "批量\(i)", content: "内容\(i)")
            XCTAssertTrue(result)
        }
        XCTAssertEqual(notesService.noteIndexes.count, 3)

        // When - 批量删除其中两条
        let allNotes = await notesService.getAllNotes()
        let toDelete = allNotes.filter { $0.title != "批量2" }
        XCTAssertEqual(toDelete.count, 2)
        let deleted = await notesService.deleteNotes(toDelete)

        // Then - 只剩未被删除的一条
        XCTAssertTrue(deleted, "批量删除应该成功")
        XCTAssertEqual(notesService.noteIndexes.count, 1)
        XCTAssertEqual(notesService.noteIndexes.first?.title, "批量2", "应保留未被删除的笔记")
        let storedCount = try await mockStorage.count()
        XCTAssertEqual(storedCount, 1, "存储层也应只剩一条")
    }

    /// 搜索正文命中：关键词位于 200 字预览之外时，经全文读取仍能命中（非仅标题/预览匹配）
    func testSearchHitsBodyBeyondPreviewFlow() async throws {
        // Given - 关键词只出现在正文 200 字预览之后
        let filler = String(repeating: "填充内容无关键词。", count: 30) // 270 字，超出预览长度
        _ = await notesService.createNote(title: "正文笔记", content: filler + "zebraUnicorn")
        _ = await notesService.createNote(title: "无关笔记", content: "完全不同的内容")

        // When - 搜索正文关键词
        let hits = await notesService.searchNotes(query: "zebraUnicorn")

        // Then - 只命中正文包含关键词的笔记
        XCTAssertEqual(hits.count, 1, "应只命中正文包含关键词的笔记")
        XCTAssertEqual(hits.first?.title, "正文笔记")
    }

    /// 持久化流程：数据预置在存储中，新服务实例启动后加载（模拟应用重启）
    func testReloadAfterRestartFlow() async throws {
        // Given - 直接向存储预置两条笔记（模拟上次运行保存的数据）
        let noteA = Note(title: "重启保留A", content: "内容A", isFavorite: true)
        let noteB = Note(title: "普通标题B", content: "内容B", tags: ["重启标签"])
        try await mockStorage.create([noteA, noteB])

        // When - 用同一存储创建新服务实例并加载索引
        let restartedService = NotesService(storage: mockStorage)
        await restartedService.loadNoteIndexes()

        // Then - 索引与完整内容均可用
        XCTAssertEqual(restartedService.noteIndexes.count, 2, "重启后应加载全部索引")
        let fetchedLoaded = await restartedService.getNote(id: noteA.id)
        let loaded = try XCTUnwrap(fetchedLoaded)
        XCTAssertEqual(loaded.title, "重启保留A")
        XCTAssertTrue(loaded.isFavorite, "收藏状态应持久化")

        // Then - 重启后搜索正常（标题与标签各命中一条）
        let titleHits = await restartedService.searchNotes(query: "重启保留")
        XCTAssertEqual(titleHits.map(\.id), [noteA.id], "标题应命中")
        let tagHits = await restartedService.searchNotes(query: "重启标签")
        XCTAssertEqual(tagHits.map(\.id), [noteB.id], "标签应命中")
    }
}
