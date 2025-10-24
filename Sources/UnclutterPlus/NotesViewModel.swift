import Combine
import Foundation
import SwiftUI

/// NotesView 的视图模型
/// 职责: 管理笔记视图的状态、布局和笔记操作
final class NotesViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 当前选中的笔记
    @Published var selectedNote: Note?

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

    /// 侧边栏宽度
    @Published var sidebarWidth: CGFloat = 300

    /// 显示标签编辑器标志
    @Published var showingTagEditor: Bool = false

    // MARK: - Dependencies

    private let notesManager: NotesManager
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Public Computed Properties (暴露 NotesManager 必要属性)

    var searchText: String {
        get { notesManager.searchText }
        set { notesManager.searchText = newValue }
    }

    var filteredNotes: [Note] {
        notesManager.filteredNotes
    }

    var selectedNotes: Set<UUID> {
        notesManager.selectedNotes
    }

    var sortOption: NotesSortOption {
        get { notesManager.sortOption }
        set { notesManager.sortOption = newValue }
    }

    var isAscending: Bool {
        get { notesManager.isAscending }
        set { notesManager.isAscending = newValue }
    }

    var allTags: [String] {
        notesManager.allTags
    }

    // MARK: - Initialization

    init(notesManager: NotesManager = .shared) {
        self.notesManager = notesManager
        observeChanges()
    }

    // MARK: - Public Methods

    /// 视图出现时调用
    func onAppear() {
        // 如果没有选中笔记,选中第一个
        if selectedNote == nil, let firstNote = notesManager.filteredNotes.first {
            selectedNote = firstNote
        }
    }

    /// 创建新笔记
    func createNewNote() {
        guard !newNoteTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let note = notesManager.createNote(
            title: newNoteTitle,
            tags: newNoteTags
        )

        selectedNote = note
        newNoteTitle = ""
        newNoteTags.removeAll()
        showingNewNoteDialog = false

        // 通知 WindowManager 开始编辑笔记
        notifyEditingState(true)
    }

    /// 删除笔记
    func deleteNote(_ note: Note) {
        notesManager.deleteNote(note)

        // 如果删除的是当前选中的笔记,清空选择
        if selectedNote?.id == note.id {
            selectedNote = notesManager.filteredNotes.first
        }
    }

    /// 删除多个笔记
    func deleteNotes(_ notes: [Note]) {
        notes.forEach { notesManager.deleteNote($0) }

        // 如果删除的包含当前选中的笔记,清空选择
        if let current = selectedNote, notes.contains(where: { $0.id == current.id }) {
            selectedNote = notesManager.filteredNotes.first
        }
    }

    /// 切换收藏状态
    func toggleFavorite(_ note: Note) {
        notesManager.toggleFavorite(note)
    }

    /// 切换笔记选择状态
    func toggleSelection(_ note: Note) {
        notesManager.toggleSelection(note)
    }

    /// 全选
    func selectAll() {
        notesManager.selectAll()
    }

    /// 取消全选
    func deselectAll() {
        notesManager.deselectAll()
    }

    /// 更新笔记
    func updateNote(_ note: Note) {
        notesManager.updateNote(note)
    }

    /// 更新笔记内容
    func updateNoteContent(_ note: Note, content: String) {
        var updated = note
        updated.content = content
        notesManager.updateNote(updated)
    }

    /// 更新笔记标题
    func updateNoteTitle(_ note: Note, title: String) {
        var updated = note
        updated.title = title
        notesManager.updateNote(updated)
    }

    /// 更新笔记标签
    func updateNoteTags(_ note: Note, tags: [String]) {
        var updated = note
        updated.tags = Set(tags)
        notesManager.updateNote(updated)
    }

    /// 切换视图布局
    func switchLayout(to layout: ViewLayout) {
        viewLayout = layout
    }

    /// 切换多选模式
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
    }

    /// 显示新笔记对话框
    func showNewNoteDialog() {
        newNoteTitle = ""
        newNoteTags.removeAll()
        showingNewNoteDialog = true
    }

    /// 隐藏新笔记对话框
    func hideNewNoteDialog() {
        showingNewNoteDialog = false
        newNoteTitle = ""
        newNoteTags.removeAll()
    }

    /// 选择笔记
    func selectNote(_ note: Note?) {
        selectedNote = note

        // 通知编辑状态
        if note != nil {
            notifyEditingState(true)
        }
    }

    /// 获取所有可用标签
    func availableTags() -> [String] {
        notesManager.allTags
    }

    /// 笔记编辑开始
    func noteEditingDidBegin() {
        notifyEditingState(true)
    }

    /// 笔记编辑结束
    func noteEditingDidEnd() {
        notifyEditingState(false)
    }

    // MARK: - Private Methods

    /// 监听变化
    private func observeChanges() {
        // 监听 NotesManager 的变化
        notesManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// 通知窗口管理器编辑状态
    private func notifyEditingState(_ isEditing: Bool) {
        WindowManager.shared.setEditingNote(isEditing)
    }
}
