import XCTest
import Foundation
@testable import UnclutterPlus
import Combine

/// NotesService 单元测试
final class NotesServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var notesService: NotesService!
    var testNote: Note!
    var cancellables: Set<AnyCancellable>!
    
    // MARK - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // 创建测试用的笔记服务
        notesService = NotesService()
        cancellables = Set<AnyCancellable>()
        
        // 创建测试笔记
        testNote = Note(
            title: "Test Note",
            content: "This is a test note content.",
            tags: ["test", "unit-test"],
            isFavorite: false
        )
    }
    
    override func tearDown() {
        notesService = nil
        testNote = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    /// 测试创建笔记
    func testCreateNote() async throws {
        // Given
        let title = "New Test Note"
        let content = "Test content"
        let tags: Set<String> = ["test"]
        
        // When
        let result = await notesService.createNote(title: title, content: content, tags: tags)
        
        // Then
        XCTAssertTrue(result, "笔记创建应该成功")
        
        // 验证笔记被添加到索引中
        XCTAssertFalse(notesService.noteIndexes.isEmpty, "笔记索引应该包含新笔记")
    }
    
    /// 测试更新笔记
    func testUpdateNote() async throws {
        // Given
        _ = await notesService.createNote(title: "Original Title", content: "Original Content")
        let originalNote = notesService.noteIndexes.first!
        let fullNote = await notesService.getNote(id: originalNote.id)
        
        guard let noteToUpdate = fullNote else {
            XCTFail("应该能够获取完整的笔记")
            return
        }
        
        // When
        let updatedContent = "Updated content"
        let result = await notesService.updateNote(noteToUpdate, content: updatedContent)
        
        // Then
        XCTAssertTrue(result, "笔记更新应该成功")
        
        // 验证内容已更新
        let updatedNote = await notesService.getNote(id: originalNote.id)
        XCTAssertEqual(updatedNote?.content, updatedContent, "笔记内容应该已更新")
    }
    
    /// 测试删除笔记
    func testDeleteNote() async throws {
        // Given
        _ = await notesService.createNote(title: "Note to Delete", content: "Content")
        let noteToDelete = notesService.noteIndexes.first!
        let originalCount = notesService.noteIndexes.count
        
        // When
        let fullNote = await notesService.getNote(id: noteToDelete.id)
        guard let note = fullNote else {
            XCTFail("应该能够获取笔记")
            return
        }
        
        let result = await notesService.deleteNote(note)
        
        // Then
        XCTAssertTrue(result, "笔记删除应该成功")
        XCTAssertEqual(notesService.noteIndexes.count, originalCount - 1, "笔记数量应该减少")
    }
    
    /// 测试切换收藏状态
    func testToggleFavorite() async throws {
        // Given
        _ = await notesService.createNote(title: "Favorite Note", content: "Content")
        let note = notesService.noteIndexes.first!
        let originalFavoriteStatus = note.isFavorite
        
        let fullNote = await notesService.getNote(id: note.id)
        guard let noteToToggle = fullNote else {
            XCTFail("应该能够获取笔记")
            return
        }
        
        // When
        let result = await notesService.toggleFavorite(noteToToggle)
        
        // Then
        XCTAssertTrue(result, "收藏状态切换应该成功")
        
        let updatedNote = await notesService.getNote(id: note.id)
        XCTAssertEqual(updatedNote?.isFavorite, !originalFavoriteStatus, "收藏状态应该被切换")
    }
    
    /// 测试搜索功能
    func testSearchNotes() async throws {
        // Given
        await notesService.createNote(title: "Swift Tutorial", content: "Learn Swift programming", tags: ["programming"])
        await notesService.createNote(title: "UI Design", content: "User interface design tips", tags: ["design"])
        
        // When
        let searchResults = await notesService.searchNotes(query: "Swift")
        
        // Then
        XCTAssertFalse(searchResults.isEmpty, "搜索应该返回结果")
        XCTAssertEqual(searchResults.count, 1, "应该只找到一个匹配的结果")
        XCTAssertEqual(searchResults.first?.title, "Swift Tutorial", "搜索结果应该匹配正确的笔记")
    }
    
    /// 测试搜索功能 - 无匹配结果
    func testSearchNotesNoMatch() async throws {
        // Given
        await notesService.createNote(title: "Random Note", content: "Content", tags: [])
        
        // When
        let searchResults = await notesService.searchNotes(query: "Nonexistent")
        
        // Then
        XCTAssertTrue(searchResults.isEmpty, "不存在的搜索词应该返回空结果")
    }
    
    /// 测试过滤功能
    func testFilterNotes() async throws {
        // Given
        await notesService.createNote(title: "Favorite Note 1", content: "Content 1", tags: ["fav"])
        await notesService.createNote(title: "Regular Note", content: "Content 2", tags: ["regular"])
        await notesService.createNote(title: "Favorite Note 2", content: "Content 3", tags: ["fav"])
        
        // 设置搜索文本为空（确保不过滤）
        notesService.searchText = ""
        
        // When
        let filteredNotes = notesService.filteredNotes
        
        // Then
        XCTAssertEqual(filteredNotes.count, 3, "应该返回所有笔记")
    }
    
    /// 测试排序功能
    func testSorting() async throws {
        // Given
        await notesService.createNote(title: "A Note", content: "Content A")
        await notesService.createNote(title: "B Note", content: "Content B")
        await notesService.createNote(title: "C Note", content: "Content C")
        
        // When - 按标题升序排序
        notesService.sortOption = .title
        notesService.isAscending = true
        
        let sortedNotes = notesService.filteredNotes
        
        // Then
        XCTAssertEqual(sortedNotes.count, 3, "应该有3个笔记")
        XCTAssertEqual(sortedNotes[0].title, "A Note", "第一个笔记应该是A")
        XCTAssertEqual(sortedNotes[1].title, "B Note", "第二个笔记应该是B")
        XCTAssertEqual(sortedNotes[2].title, "C Note", "第三个笔记应该是C")
    }
    
    /// 测试统计信息
    func testStatistics() async throws {
        // Given
        await notesService.createNote(title: "Note 1", content: "Content 1")
        await notesService.createNote(title: "Note 2", content: "Content 2", tags: ["tag1"])
        await notesService.createNote(title: "Note 3", content: "Content 3", tags: ["tag1", "tag2"])
        
        // When
        let statistics = await notesService.getStatistics()
        
        // Then
        XCTAssertEqual(statistics.totalNotes, 3, "笔记总数应该为3")
        XCTAssertTrue(statistics.favoriteNotes >= 0, "收藏笔记数应该非负")
        XCTAssertTrue(statistics.totalWords > 0, "总字数应该大于0")
    }
    
    /// 测试空状态处理
    func testEmptyState() async throws {
        // Given - 确保没有笔记
        await notesService.deleteNotes(notesService.noteIndexes.map { note in
            // 获取完整笔记
            Task {
                await notesService.getNote(id: note.id)
            }
        }.compactMap { note in
            note
        })
        
        // When
        let noteIndexes = notesService.noteIndexes
        
        // Then
        XCTAssertTrue(noteIndexes.isEmpty, "笔记列表应该为空")
    }
    
    /// 测试错误处理 - 创建空标题笔记
    func testCreateNoteWithEmptyTitle() async throws {
        // Given
        let emptyTitle = ""
        
        // When
        let result = await notesService.createNote(title: emptyTitle, content: "Content")
        
        // Then
        XCTAssertFalse(result, "创建空标题笔记应该失败")
    }
    
    /// 测试数据持久化
    func testDataPersistence() async throws {
        // Given
        _ = await notesService.createNote(title: "Persistent Note", content: "This should persist")
        let noteId = notesService.noteIndexes.first!.id
        
        // When - 重新创建服务实例（模拟重启）
        let newService = NotesService()
        await newService.loadNoteIndexes()
        
        // Then
        let persistedNote = await newService.getNote(id: noteId)
        XCTAssertNotNil(persistedNote, "笔记应该持久化保存")
    }
    
    // MARK: - Performance Tests
    
    /// 测试大量笔记创建性能
    func testCreateManyNotesPerformance() async throws {
        // Given
        let noteCount = 100
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<noteCount {
            _ = await notesService.createNote(
                title: "Performance Test Note \(i)",
                content: "Content for note \(i)"
            )
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Then
        XCTAssertLessThan(duration, 5.0, "创建100个笔记应该在5秒内完成")
        print("Performance: Created \(noteCount) notes in \(String(format: "%.3f", duration)) seconds")
    }
    
    /// 测试搜索性能
    func testSearchPerformance() async throws {
        // Given
        for i in 0..<50 {
            await notesService.createNote(
                title: "Search Test Note \(i)",
                content: "This is a searchable content with index \(i)"
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let searchResults = await notesService.searchNotes(query: "searchable")
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Then
        XCTAssertLessThan(duration, 1.0, "搜索应该在1秒内完成")
        XCTAssertFalse(searchResults.isEmpty, "应该找到搜索结果")
        print("Performance: Search completed in \(String(format: "%.3f", duration)) seconds")
    }
    
    // MARK: - Memory Tests
    
    /// 测试内存使用
    func testMemoryUsage() async throws {
        // Given
        let initialMemory = getMemoryUsage()
        
        // 创建大量笔记
        for i in 0..<200 {
            _ = await notesService.createNote(
                title: "Memory Test Note \(i)",
                content: String(repeating: "Content ", count: 1000)
            )
        }
        
        // When
        let peakMemory = getMemoryUsage()
        
        // Then
        let memoryIncrease = peakMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "内存增长应该小于50MB")
        print("Memory usage: Initial: \(initialMemory / 1024 / 1024)MB, Peak: \(peakMemory / 1024 / 1024)MB, Increase: \(memoryIncrease / 1024 / 1024)MB")
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: task_info_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Test Suite

extension NotesServiceTests {
    static var allTests = [
        ("testCreateNote", testCreateNote),
        ("testUpdateNote", testUpdateNote),
        ("testDeleteNote", testDeleteNote),
        ("testToggleFavorite", testToggleFavorite),
        ("testSearchNotes", testSearchNotes),
        ("testSearchNotesNoMatch", testSearchNotesNoMatch),
        ("testFilterNotes", testFilterNotes),
        ("testSorting", testSorting),
        ("testStatistics", testStatistics),
        ("testEmptyState", testEmptyState),
        ("testCreateNoteWithEmptyTitle", testCreateNoteWithEmptyTitle),
        ("testDataPersistence", testDataPersistence),
        ("testCreateManyNotesPerformance", testCreateManyNotesPerformance),
        ("testSearchPerformance", testSearchPerformance),
        ("testMemoryUsage", testMemoryUsage)
    ]
}
