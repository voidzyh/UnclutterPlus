import Foundation
import Combine
import AppKit

/// 笔记管理器 - 管理所有笔记的创建、编辑、删除和搜索
class NotesManager: ObservableObject {
    static let shared = NotesManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var notes: [Note] = []
    @Published private(set) var filteredNotes: [Note] = []
    @Published private(set) var allTags: Set<String> = []
    @Published private(set) var pinnedNotes: [Note] = []
    
    // 搜索和过滤
    @Published var searchText: String = "" {
        didSet {
            debouncedSearch.send(searchText)
        }
    }
    @Published var selectedTags: Set<String> = []
    @Published var sortOption: NoteSortOption = .dateModified
    @Published var isAscending: Bool = false
    
    // 状态管理
    @Published var isLoading = false
    @Published var error: NotesError?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let debouncedSearch = PassthroughSubject<String, Never>()
    private let fileManager = FileManager.default
    
    /// 笔记存储目录
    private var notesDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("UnclutterPlus")
        let notesDirectory = appDirectory.appendingPathComponent("Notes")
        
        if !fileManager.fileExists(atPath: notesDirectory.path) {
            try? fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        }
        
        return notesDirectory
    }
    
    /// 笔记索引文件路径
    private var notesIndexFile: URL {
        notesDirectory.appendingPathComponent("notes_index.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        setupBindings()
        setupDebouncedSearch()
        loadNotes()
        createWelcomeNoteIfNeeded()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 监听标签选择变化
        $selectedTags
            .sink { [weak self] _ in
                self?.updateFilteredNotes()
            }
            .store(in: &cancellables)
        
        // 监听排序选项变化
        $sortOption
            .sink { [weak self] _ in
                self?.updateFilteredNotes()
            }
            .store(in: &cancellables)
        
        // 监听排序顺序变化
        $isAscending
            .sink { [weak self] _ in
                self?.updateFilteredNotes()
            }
            .store(in: &cancellables)
    }
    
    private func setupDebouncedSearch() {
        debouncedSearch
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFilteredNotes()
            }
            .store(in: &cancellables)
    }
    
    /// 加载笔记索引
    private func loadNotes() {
        guard fileManager.fileExists(atPath: notesIndexFile.path) else {
            notes = []
            filteredNotes = []
            return
        }
        
        do {
            let data = try Data(contentsOf: notesIndexFile)
            let decoder = JSONDecoder()
            let loadedNotes = try decoder.decode([Note].self, from: data)
            
            // 过滤掉不存在的笔记文件
            notes = loadedNotes.filter { note in
                let noteFile = notesDirectory.appendingPathComponent("\(note.id).json")
                return fileManager.fileExists(atPath: noteFile.path)
            }
            
            updateFilteredNotes()
            updateAllTags()
            updatePinnedNotes()
        } catch {
            logger.info("Failed to load notes: \(error)", category: "NotesManager")
            self.error = .loadFailed(error.localizedDescription)
            notes = []
            filteredNotes = []
        }
    }
    
    /// 保存笔记索引
    private func saveNotes() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(notes)
            try data.write(to: notesIndexFile)
            
            // 发送更新通知
            NotificationCenter.default.post(name: Notification.Name("NotesUpdated"), object: nil)
        } catch {
            logger.info("Failed to save notes: \(error)", category: "NotesManager")
            self.error = .saveFailed(error.localizedDescription)
        }
    }
    
    /// 更新过滤后的笔记
    private func updateFilteredNotes() {
        var filtered = notes
        
        // 应用搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // 应用标签过滤
        if !selectedTags.isEmpty {
            filtered = filtered.filter { note in
                !note.tags.filter { selectedTags.contains($0) }.isEmpty
            }
        }
        
        // 应用排序
        filtered.sort { note1, note2 in
            let comparison: Bool
            switch sortOption {
            case .dateCreated:
                comparison = note1.createdAt < note2.createdAt
            case .dateModified:
                comparison = note1.updatedAt < note2.updatedAt
            case .title:
                comparison = note1.title.localizedStandardCompare(note2.title) == .orderedAscending
            case .tagCount:
                comparison = note1.tags.count < note2.tags.count
            }
            
            return isAscending ? comparison : !comparison
        }
        
        // 将置顶笔记放在前面
        filtered.sort { $0.isPinned && !$1.isPinned }
        
        filteredNotes = filtered
    }
    
    /// 更新所有标签
    private func updateAllTags() {
        allTags = Set(notes.flatMap { $0.tags })
    }
    
    /// 更新置顶笔记
    private func updatePinnedNotes() {
        pinnedNotes = notes.filter { $0.isPinned }
    }
    
    /// 创建欢迎笔记（如果不存在任何笔记）
    private func createWelcomeNoteIfNeeded() {
        guard notes.isEmpty else { return }
        
        let welcomeNote = Note(
            id: UUID(),
            title: "Welcome to UnclutterPlus!",
            content: """
            Welcome to your new note-taking app!
            
            Here are some tips to get started:
            • Click the + button to create a new note
            • Use tags to organize your notes
            • Pin important notes to keep them at the top
            • Search through all your notes quickly
            
            Happy note-taking!
            """,
            tags: ["welcome", "tutorial"],
            isPinned: true,
            createdAt: Date(),
            updatedAt: Date(),
            attachments: []
        )
        
        notes = [welcomeNote]
        saveNotes()
    }
    
    // MARK: - Public Methods
    
    func createNote(title: String, content: String, tags: [String] = [], attachments: [NoteAttachment] = []) {
        let newNote = Note(
            id: UUID(),
            title: title,
            content: content,
            tags: tags,
            isPinned: false,
            createdAt: Date(),
            updatedAt: Date(),
            attachments: attachments
        )
        
        notes.insert(newNote, at: 0)
        saveNotes()
        updateFilteredNotes()
        updateAllTags()
    }
    
    func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            saveNotes()
            updateFilteredNotes()
            updateAllTags()
        }
    }
    
    func deleteNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes.remove(at: index)
            saveNotes()
            updateFilteredNotes()
            updateAllTags()
            updatePinnedNotes()
        }
    }
    
    func togglePin(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isPinned.toggle()
            saveNotes()
            updateFilteredNotes()
            updatePinnedNotes()
        }
    }
    
    func addTag(_ tag: String, to note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            if !notes[index].tags.contains(tag) {
                notes[index].tags.append(tag)
                saveNotes()
                updateAllTags()
            }
        }
    }
    
    func removeTag(_ tag: String, from note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].tags.removeAll { $0 == tag }
            saveNotes()
            updateAllTags()
        }
    }
    
    func refresh() async {
        loadNotes()
    }
    
    func clearSearch() {
        searchText = ""
        selectedTags.removeAll()
    }
    
    func toggleFavorite(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isFavorite.toggle()
            saveNotes()
            updateFilteredNotes()
        }
    }
    
    func deleteAllNotes() {
        notes.removeAll()
        saveNotes()
        updateFilteredNotes()
        updateAllTags()
        updatePinnedNotes()
    }
    
    func exportNotes(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(notes)
        try data.write(to: url)
    }
    
    func importNotes(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let importedNotes = try decoder.decode([Note].self, from: data)
        
        // 合并导入的笔记，避免重复
        for importedNote in importedNotes {
            if !notes.contains(where: { $0.id == importedNote.id }) {
                notes.append(importedNote)
            }
        }
        
        saveNotes()
        updateFilteredNotes()
        updateAllTags()
        updatePinnedNotes()
    }
    
    // MARK: - 新增方法以修复构建错误
    
    func getAllNotes() async throws -> [Note] {
        return notes
    }
    
    var notesPublisher: AnyPublisher<[Note], Never> {
        // 创建一个简单的发布者，当笔记变化时发送更新
        NotificationCenter.default
            .publisher(for: Notification.Name("NotesUpdated"))
            .map { _ in self.notes }
            .prepend(notes)
            .eraseToAnyPublisher()
    }
}