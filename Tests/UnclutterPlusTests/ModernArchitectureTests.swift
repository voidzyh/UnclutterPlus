import XCTest
import SwiftUI
import Combine
@testable import UnclutterPlus

/// 现代化架构测试套件 - 验证新架构的正确性和性能
@MainActor
final class ModernArchitectureTests: XCTestCase {
    
    // MARK: - 属性
    
    private var cancellables: Set<AnyCancellable> = []
    private var testExpectation: XCTestExpectation!
    
    // MARK: - 生命周期
    
    override func setUp() {
        super.setUp()
        cancellables = []
        testExpectation = nil
    }
    
    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - 设计系统测试
    
    func testModernDesignSystemInitialization() {
        // Given
        let designSystem = ModernDesignSystem.shared
        
        // When
        let currentTheme = designSystem.currentTheme
        let colorScheme = designSystem.colorScheme
        
        // Then
        XCTAssertEqual(currentTheme, .system)
        XCTAssertEqual(colorScheme, .light)
        XCTAssertNotNil(designSystem.springAnimation)
        XCTAssertNotNil(designSystem.smoothAnimation)
        XCTAssertNotNil(designSystem.snappyAnimation)
        XCTAssertNotNil(designSystem.fluidAnimation)
    }
    
    func testThemeSwitching() {
        // Given
        let designSystem = ModernDesignSystem.shared
        let expectation = XCTestExpectation(description: "Theme switched")
        
        // When
        designSystem.$currentTheme
            .dropFirst()
            .sink { theme in
                XCTAssertEqual(theme, .dark)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        designSystem.switchTheme(.dark)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testColorSystem() {
        // Given
        let designSystem = ModernDesignSystem.shared
        
        // When
        let brandPrimary = Color.brandPrimary
        let adaptiveBackground = Color.adaptiveBackground
        let gradientStart = Color.gradientStart
        
        // Then
        XCTAssertNotNil(brandPrimary)
        XCTAssertNotNil(adaptiveBackground)
        XCTAssertNotNil(gradientStart)
    }
    
    // MARK: - 主视图测试
    
    func testModernMainContentViewInitialization() {
        // Given
        let viewModel = ModernMainContentViewModel()
        
        // When
        let enabledTabs = viewModel.enabledTabs
        let selectedTab = viewModel.selectedTab
        
        // Then
        XCTAssertEqual(enabledTabs.count, 3)
        XCTAssertEqual(enabledTabs, ["files", "clipboard", "notes"])
        XCTAssertEqual(selectedTab, 0)
    }
    
    func testTabSwitching() {
        // Given
        let viewModel = ModernMainContentViewModel()
        let expectation = XCTestExpectation(description: "Tab switched")
        
        // When
        viewModel.$selectedTab
            .dropFirst()
            .sink { tab in
                XCTAssertEqual(tab, 1)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.selectedTab = 1
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 剪贴板视图测试
    
    func testModernClipboardViewModelInitialization() {
        // Given
        let viewModel = ModernClipboardViewModel()
        
        // When
        let initialItems = viewModel.clipboardItems
        let searchText = viewModel.searchText
        let selectedContentType = viewModel.selectedContentType
        
        // Then
        XCTAssertEqual(initialItems.count, 0)
        XCTAssertEqual(searchText, "")
        XCTAssertEqual(selectedContentType, .all)
    }
    
    func testClipboardFiltering() async {
        // Given
        let viewModel = ModernClipboardViewModel()
        let testItems = createTestClipboardItems()
        
        // When
        viewModel.clipboardItems = testItems
        viewModel.searchText = "test"
        
        // 等待搜索完成
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // Then
        XCTAssertFalse(viewModel.filteredItems.isEmpty)
        XCTAssertTrue(viewModel.filteredItems.allSatisfy { $0.preview.contains("test") })
    }
    
    func testClipboardSorting() {
        // Given
        let viewModel = ModernClipboardViewModel()
        let testItems = createTestClipboardItems()
        
        // When
        viewModel.clipboardItems = testItems
        viewModel.sortOption = .newest
        
        // Then
        let sortedItems = viewModel.filteredItems
        for i in 1..<sortedItems.count {
            XCTAssertGreaterThanOrEqual(sortedItems[i-1].timestamp, sortedItems[i].timestamp)
        }
    }
    
    // MARK: - 笔记视图测试
    
    func testModernNotesViewModelInitialization() {
        // Given
        let viewModel = ModernNotesViewModel()
        
        // When
        let initialNotes = viewModel.notes
        let searchText = viewModel.searchText
        let newNoteTitle = viewModel.newNoteTitle
        
        // Then
        XCTAssertEqual(initialNotes.count, 0)
        XCTAssertEqual(searchText, "")
        XCTAssertEqual(newNoteTitle, "")
    }
    
    func testNoteCreation() async {
        // Given
        let viewModel = ModernNotesViewModel()
        let title = "Test Note"
        let content = "This is a test note content"
        
        // When
        viewModel.createNote(title: title, content: content)
        
        // 等待创建完成
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // Then
        XCTAssertFalse(viewModel.notes.isEmpty)
        if let firstNote = viewModel.notes.first {
            XCTAssertEqual(firstNote.title, title)
            XCTAssertEqual(firstNote.content, content)
        }
    }
    
    func testMarkdownToolInsertion() {
        // Given
        let viewModel = ModernNotesViewModel()
        let tool = MarkdownTool.bold
        
        // When
        viewModel.insertMarkdownTool(tool)
        
        // Then
        XCTAssertEqual(viewModel.newNoteContent, "\n\n**bold text**")
    }
    
    // MARK: - 文件视图测试
    
    func testModernFilesViewModelInitialization() {
        // Given
        let viewModel = ModernFilesViewModel()
        
        // When
        let initialFiles = viewModel.files
        let searchText = viewModel.searchText
        let viewMode = viewModel.viewMode
        
        // Then
        XCTAssertEqual(initialFiles.count, 0)
        XCTAssertEqual(searchText, "")
        XCTAssertEqual(viewMode, .grid)
    }
    
    func testFileSorting() {
        // Given
        let viewModel = ModernFilesViewModel()
        let testFiles = createTestFiles()
        
        // When
        viewModel.files = testFiles
        viewModel.sortOption = .nameAscending
        
        // Then
        let sortedFiles = viewModel.filteredFiles
        for i in 1..<sortedFiles.count {
            XCTAssertLessThanOrEqual(sortedFiles[i-1].name, sortedFiles[i].name)
        }
    }
    
    func testFileSelection() {
        // Given
        let viewModel = ModernFilesViewModel()
        let testFiles = createTestFiles()
        let firstFile = testFiles[0]
        
        // When
        viewModel.files = testFiles
        viewModel.selectFile(firstFile)
        
        // Then
        XCTAssertTrue(viewModel.selectedFiles.contains(firstFile.id))
    }
    
    // MARK: - 窗口管理器测试
    
    func testModernWindowManagerInitialization() {
        // Given
        let windowManager = ModernWindowManager.shared
        
        // When
        let isVisible = windowManager.isWindowVisible
        let windowSize = windowManager.windowSize
        let isEdgeTracking = windowManager.isEdgeTracking
        
        // Then
        XCTAssertFalse(isVisible)
        XCTAssertEqual(windowSize.width, 900)
        XCTAssertEqual(windowSize.height, 600)
        XCTAssertTrue(isEdgeTracking)
    }
    
    func testWindowVisibility() {
        // Given
        let windowManager = ModernWindowManager.shared
        let expectation = XCTestExpectation(description: "Window visibility changed")
        
        // When
        windowManager.$isWindowVisible
            .dropFirst()
            .sink { visible in
                XCTAssertTrue(visible)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        windowManager.showWindow()
        
        // Then
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - 性能优化器测试
    
    func testPerformanceOptimizerInitialization() {
        // Given
        let optimizer = PerformanceOptimizer.shared
        
        // When
        let memoryUsage = optimizer.memoryUsage
        let cpuUsage = optimizer.cpuUsage
        let performanceScore = optimizer.performanceScore
        
        // Then
        XCTAssertGreaterThanOrEqual(memoryUsage, 0)
        XCTAssertGreaterThanOrEqual(cpuUsage, 0)
        XCTAssertGreaterThanOrEqual(performanceScore, 0)
        XCTAssertLessThanOrEqual(performanceScore, 100)
    }
    
    func testCacheOperations() {
        // Given
        let optimizer = PerformanceOptimizer.shared
        let testKey = "test_key"
        let testData = "test_data".data(using: .utf8)!
        
        // When
        optimizer.cacheData(testData, for: testKey)
        let cachedData = optimizer.cachedData(for: testKey)
        
        // Then
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData, testData)
    }
    
    func testThrottleFunction() {
        // Given
        let optimizer = PerformanceOptimizer.shared
        let key = "test_throttle"
        var callCount = 0
        
        // When
        for _ in 0..<5 {
            optimizer.throttle(key: key, interval: 0.1) {
                callCount += 1
            }
        }
        
        // 等待节流时间
        let expectation = XCTestExpectation(description: "Throttle completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.3)
        
        // Then
        XCTAssertEqual(callCount, 1) // 应该只被调用一次
    }
    
    func testDebounceFunction() {
        // Given
        let optimizer = PerformanceOptimizer.shared
        let key = "test_debounce"
        var callCount = 0
        
        // When
        for _ in 0..<5 {
            optimizer.debounce(key: key, interval: 0.1) {
                callCount += 1
            }
        }
        
        // 等待防抖时间
        let expectation = XCTestExpectation(description: "Debounce completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.3)
        
        // Then
        XCTAssertEqual(callCount, 1) // 应该只被调用一次
    }
    
    // MARK: - 动画系统测试
    
    func testModernAnimations() {
        // Given
        let springAnimation = ModernAnimations.spring
        let smoothAnimation = ModernAnimations.smooth
        let snappyAnimation = ModernAnimations.snappy
        
        // Then
        XCTAssertNotNil(springAnimation)
        XCTAssertNotNil(smoothAnimation)
        XCTAssertNotNil(snappyAnimation)
    }
    
    func testAnimationTransitions() {
        // Given
        let cardEnter = AnyTransition.cardEnter
        let modalAppear = AnyTransition.modalAppear
        let tabSwitch = AnyTransition.tabSwitch
        
        // Then
        XCTAssertNotNil(cardEnter)
        XCTAssertNotNil(modalAppear)
        XCTAssertNotNil(tabSwitch)
    }
    
    // MARK: - 集成测试
    
    func testFullFeatureIntegration() async {
        // Given
        let windowManager = ModernWindowManager.shared
        let clipboardVM = ModernClipboardViewModel()
        let notesVM = ModernNotesViewModel()
        let filesVM = ModernFilesViewModel()
        
        // When - 模拟完整的使用流程
        windowManager.showWindow()
        
        // 添加剪贴板项目
        let testClipboardItem = ClipboardItem(
            content: .text("Test clipboard item"),
            timestamp: Date()
        )
        clipboardVM.clipboardItems = [testClipboardItem]
        
        // 添加笔记
        notesVM.createNote(title: "Test Note", content: "Test content")
        
        // 添加文件
        let testFile = TempFile(
            id: UUID(),
            name: "test.txt",
            url: URL(fileURLWithPath: "/tmp/test.txt"),
            size: 1024,
            type: "text/plain",
            createdAt: Date()
        )
        filesVM.files = [testFile]
        
        // 等待所有操作完成
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // Then
        XCTAssertTrue(windowManager.isWindowVisible)
        XCTAssertFalse(clipboardVM.clipboardItems.isEmpty)
        XCTAssertFalse(notesVM.notes.isEmpty)
        XCTAssertFalse(filesVM.files.isEmpty)
        
        // 清理
        windowManager.hideWindow()
    }
    
    func testPerformanceUnderLoad() {
        // Given
        let optimizer = PerformanceOptimizer.shared
        let initialScore = optimizer.performanceScore
        
        // When - 创建大量数据来模拟负载
        let largeDataSet = (0..<1000).map { index in
            ClipboardItem(
                content: .text("Test item \(index) with some longer content to simulate real usage"),
                timestamp: Date().addingTimeInterval(-Double(index) * 60)
            )
        }
        
        let clipboardVM = ModernClipboardViewModel()
        clipboardVM.clipboardItems = largeDataSet
        
        // 执行搜索和过滤
        clipboardVM.searchText = "Test"
        clipboardVM.sortOption = .newest
        clipboardVM.selectedContentType = .text
        
        // 等待处理完成
        let expectation = XCTestExpectation(description: "Processing completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        // Then
        XCTAssertFalse(clipboardVM.filteredItems.isEmpty)
        XCTAssertGreaterThanOrEqual(optimizer.performanceScore, initialScore - 20) // 性能下降不应超过20分
    }
    
    // MARK: - 辅助方法
    
    private func createTestClipboardItems() -> [ClipboardItem] {
        return [
            ClipboardItem(content: .text("Test item 1"), timestamp: Date().addingTimeInterval(-60)),
            ClipboardItem(content: .text("Another test item"), timestamp: Date().addingTimeInterval(-120)),
            ClipboardItem(content: .text("Sample test content"), timestamp: Date().addingTimeInterval(-180)),
            ClipboardItem(content: .text("Different content"), timestamp: Date().addingTimeInterval(-240))
        ]
    }
    
    private func createTestFiles() -> [TempFile] {
        return [
            TempFile(
                id: UUID(),
                name: "document.txt",
                url: URL(fileURLWithPath: "/tmp/document.txt"),
                size: 1024,
                type: "text/plain",
                createdAt: Date().addingTimeInterval(-60)
            ),
            TempFile(
                id: UUID(),
                name: "image.png",
                url: URL(fileURLWithPath: "/tmp/image.png"),
                size: 2048,
                type: "image/png",
                createdAt: Date().addingTimeInterval(-120)
            ),
            TempFile(
                id: UUID(),
                name: "data.json",
                url: URL(fileURLWithPath: "/tmp/data.json"),
                size: 512,
                type: "application/json",
                createdAt: Date().addingTimeInterval(-180)
            )
        ]
    }
}

// MARK: - UI 测试

@MainActor
final class ModernUITests: XCTestCase {
    
    func testModernMainContentViewRendering() {
        // Given
        let view = ModernMainContentView()
        
        // When
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertEqual(hostingController.view.frame.width, 900)
        XCTAssertEqual(hostingController.view.frame.height, 600)
    }
    
    func testModernClipboardViewRendering() {
        // Given
        let view = ModernClipboardView()
        
        // When
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertEqual(hostingController.view.frame.width, 800)
        XCTAssertEqual(hostingController.view.frame.height, 600)
    }
    
    func testModernNotesViewRendering() {
        // Given
        let view = ModernNotesView()
        
        // When
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 1200, height: 800)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertEqual(hostingController.view.frame.width, 1200)
        XCTAssertEqual(hostingController.view.frame.height, 800)
    }
    
    func testModernFilesViewRendering() {
        // Given
        let view = ModernFilesView()
        
        // When
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 1000, height: 600)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertEqual(hostingController.view.frame.width, 1000)
        XCTAssertEqual(hostingController.view.frame.height, 600)
    }
}

// MARK: - 性能测试

@MainActor
final class ModernPerformanceTests: XCTestCase {
    
    func testViewModelPerformance() {
        // Given
        let viewModel = ModernClipboardViewModel()
        let largeDataSet = (0..<10000).map { index in
            ClipboardItem(
                content: .text("Test item \(index) with some longer content to simulate real usage"),
                timestamp: Date().addingTimeInterval(-Double(index) * 60)
            )
        }
        
        measure {
            // When
            viewModel.clipboardItems = largeDataSet
            viewModel.searchText = "Test"
            viewModel.sortOption = .newest
            viewModel.selectedContentType = .text
            
            // 等待处理完成
            let expectation = XCTestExpectation(description: "Processing completed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2.0)
        }
    }
    
    func testAnimationPerformance() {
        // Given
        let view = ModernMainContentView()
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        
        measure {
            // When - 模拟动画更新
            hostingController.view.animator().alphaValue = 0.5
            hostingController.view.animator().alphaValue = 1.0
        }
    }
    
    func testMemoryUsage() {
        // Given
        let initialMemory = getCurrentMemoryUsage()
        let viewModel = ModernClipboardViewModel()
        
        // When
        let largeDataSet = (0..<5000).map { index in
            ClipboardItem(
                content: .text("Test item \(index)"),
                timestamp: Date()
            )
        }
        
        viewModel.clipboardItems = largeDataSet
        
        // 等待处理完成
        let expectation = XCTestExpectation(description: "Processing completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // 内存增长不应超过 50MB
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024)
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size)
        }
        
        return 0
    }
}