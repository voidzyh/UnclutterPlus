import Combine
import Foundation
import SwiftUI

/// NotesView 的视图模型（使用新的 Repository 架构）
@MainActor
final class NotesViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 显示新笔记对话框标志
    @Published var showingNewNoteDialog: Bool = false

    /// 新笔记标题
    @Published var newNoteTitle: String = ""

    /// 新笔记标签
    @Published var newNoteTags: Set<String> = []

    /// 视图布局模式
    @Published var viewLayout: ViewLayout = .sidebar

    /// 多选模式标志
    @Published var isMultiSelectMode: Bool = false

    /// 选中的笔记 ID 集合（多选时使用）
    @Published var selectedNoteIds: Set<UUID> = []

    /// 侧边栏宽度
    @Published var sidebarWidth: CGFloat = 300

    /// 显示标签编辑器标志
    @Published var showingTagEditor: Bool = false

    /// 当前正在编辑的笔记内容（缓存，避免频繁保存）
    @Published var editingContent: String = ""

    /// 是否正在加载
    @Published var isLoading: Bool = false

    // MARK: - Dependencies

    private let repository: NoteRepository
    private var cancellables: Set<AnyCancellable> = []
    private var saveWorkItem: DispatchWorkItem?

    // MARK: - Public Computed Properties

    /// 当前选中的笔记
    var selectedNote: Note? {
        get { repository.selectedNote }
        set { repository.selectedNote = newValue }
    }

    /// 搜索文本
    var searchText: String {
        get { repository.searchText }
        set { repository.searchText = newValue }
    }

    /// 过滤后的笔记索引
    var filteredNotes: [NoteIndex] {
        repository.filteredIndexes
    }

    /// 排序选项
    var sortOption: NotesSortOption {
        get { repository.sortOption }
        set { repository.sortOption = newValue }
    }

    /// 是否升序
    var isAscending: Bool {
        get { repository.isAscending }
        set { repository.isAscending = newValue }
    }

    /// 所有标签
    var allTags: Set<String> {
        repository.allTags
    }

    /// 当前选中的笔记数量
    var selectedCount: Int {
        selectedNoteIds.count
    }

    // MARK: - View Layout

    enum ViewLayout: String, CaseIterable {
        case sidebar = "Sidebar"
        case focus = "Focus"
        case split = "Split"
    }

    // MARK: - Initialization

    init(repository: NoteRepository) {
        self.repository = repository
        setupBindings()
    }

    private func setupBindings() {
        // 监听选中笔记变化，更新编辑内容
        repository.$selectedNote
            .compactMap { $0 }
            .sink { [weak self] note in
                self?.editingContent = note.content
            }
            .store(in: &cancellables)

        // 监听编辑内容变化，延迟保存
        $editingContent
            .dropFirst() // 跳过初始值
            .sink { [weak self] content in
                self?.scheduleSave(content: content)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// 选择笔记
    func selectNote(_ index: NoteIndex) {
        Task {
            isLoading = true
            if let note = await repository.getNote(id: index.id) {
                selectedNote = note
                editingContent = note.content
            }
            isLoading = false
        }
    }

    /// 创建新笔记
    func createNote() {
        guard !newNoteTitle.isEmpty else { return }

        Task {
            if let note = await repository.createNote(
                title: newNoteTitle,
                content: "",
                tags: newNoteTags
            ) {
                selectedNote = note
                editingContent = ""
                newNoteTitle = ""
                newNoteTags = []
                showingNewNoteDialog = false
            }
        }
    }

    /// 删除笔记
    func deleteNote(_ index: NoteIndex) {
        Task {
            // 创建临时笔记对象用于删除
            let note = Note(title: index.title)
            var noteToDelete = note
            noteToDelete.id = index.id

            await repository.deleteNote(noteToDelete)

            // 如果删除的是当前选中的笔记，清空选择
            if selectedNote?.id == index.id {
                selectedNote = nil
                editingContent = ""
            }
        }
    }

    /// 批量删除笔记
    func deleteSelectedNotes() {
        guard !selectedNoteIds.isEmpty else { return }

        Task {
            // 创建临时笔记对象用于删除
            let notesToDelete = selectedNoteIds.compactMap { id in
                filteredNotes.first { $0.id == id }.map { index in
                    var note = Note(title: index.title)
                    note.id = id
                    return note
                }
            }

            await repository.deleteNotes(notesToDelete)
            selectedNoteIds.removeAll()
            isMultiSelectMode = false
        }
    }

    /// 切换收藏状态
    func toggleFavorite(_ index: NoteIndex) {
        Task {
            if let note = await repository.getNote(id: index.id) {
                await repository.toggleFavorite(note)
            }
        }
    }

    /// 切换多选模式
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode {
            selectedNoteIds.removeAll()
        }
    }

    /// 切换笔记选择状态
    func toggleSelection(_ index: NoteIndex) {
        if selectedNoteIds.contains(index.id) {
            selectedNoteIds.remove(index.id)
        } else {
            selectedNoteIds.insert(index.id)
        }
    }

    /// 全选
    func selectAll() {
        selectedNoteIds = Set(filteredNotes.map { $0.id })
    }

    /// 清空选择
    func deselectAll() {
        selectedNoteIds.removeAll()
    }

    /// 清空所有笔记
    func clearAllNotes() {
        Task {
            await repository.clearAll()
            selectedNote = nil
            editingContent = ""
            selectedNoteIds.removeAll()
        }
    }

    /// 显示新笔记对话框
    func showNewNoteDialog() {
        newNoteTitle = ""
        newNoteTags = []
        showingNewNoteDialog = true
    }

    /// 切换视图布局
    func switchLayout(_ layout: ViewLayout) {
        viewLayout = layout
    }

    // MARK: - Private Methods

    /// 延迟保存笔记内容
    private func scheduleSave(content: String) {
        // 取消之前的保存任务
        saveWorkItem?.cancel()

        // 创建新的延迟保存任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self,
                  var note = self.selectedNote else { return }

            // 只有内容真正改变时才保存
            if note.content != content {
                note.content = content
                Task {
                    await self.repository.updateNote(note)
                }
            }
        }

        saveWorkItem = workItem

        // 2 秒后执行保存
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    /// 立即保存当前编辑内容
    func saveCurrentNote() {
        saveWorkItem?.cancel()

        guard var note = selectedNote,
              note.content != editingContent else { return }

        note.content = editingContent

        Task {
            await repository.updateNote(note)
        }
    }
}