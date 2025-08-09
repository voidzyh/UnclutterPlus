import Foundation
import SwiftUI

struct Note: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    let createdAt: Date
    var modifiedAt: Date
    var tags: Set<String> = []
    var isFavorite: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, createdAt, modifiedAt, tags, isFavorite
    }
    
    var preview: String {
        // 提取内容的前几行作为预览，去除 Markdown 标记
        let lines = content.components(separatedBy: .newlines)
        let previewLines = Array(lines.prefix(3))
        let preview = previewLines.joined(separator: " ")
        
        // 简单去除常见的 Markdown 标记
        let cleaned = preview
            .replacingOccurrences(of: "# ", with: "")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "### ", with: "")
            .replacingOccurrences(of: "#### ", with: "")
            .replacingOccurrences(of: "##### ", with: "")
            .replacingOccurrences(of: "###### ", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "~~", with: "")
            .replacingOccurrences(of: "> ", with: "")
            .replacingOccurrences(of: "- ", with: "")
            .replacingOccurrences(of: "+ ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? "Empty note" : cleaned
    }
    
    var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    var characterCount: Int {
        return content.count
    }
    
    var readingTime: Int {
        // 假设每分钟阅读 200 个词
        return max(1, wordCount / 200)
    }
    
    var headings: [String] {
        let lines = content.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                return trimmed
            }
            return nil
        }
    }
    
    init(title: String, content: String = "", tags: Set<String> = [], isFavorite: Bool = false) {
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.tags = tags
        self.isFavorite = isFavorite
    }
}

enum NotesSortOption: String, CaseIterable {
    case modified = "Modified"
    case created = "Created"
    case title = "Title"
    case wordCount = "Word Count"
}

class NotesManager: ObservableObject {
    static let shared = NotesManager()
    
    @Published var notes: [Note] = []
    @Published var selectedNotes: Set<UUID> = []
    @Published var sortOption: NotesSortOption = .modified
    @Published var isAscending: Bool = false
    @Published var searchText: String = ""
    
    private let userDefaults = UserDefaults.standard
    private let notesKey = "SavedNotes"
    private var hasInitialized = false
    
    private init() {
        print("NotesManager: 初始化 (单例)")
        loadNotes()
        hasInitialized = true
    }
    
    func createNote(title: String, tags: Set<String> = []) -> Note {
        print("NotesManager: 创建新笔记: \(title)")
        let note = Note(title: title, tags: tags)
        notes.insert(note, at: 0)  // 新笔记添加到顶部，更容易找到
        saveNotes()
        print("NotesManager: 现有 \(notes.count) 个笔记")
        return note
    }
    
    func updateNote(_ updatedNote: Note) {
        if let index = notes.firstIndex(where: { $0.id == updatedNote.id }) {
            let oldNote = notes[index]
            
            // 检查内容是否真的改变了
            let hasChanged = oldNote.title != updatedNote.title || 
                           oldNote.content != updatedNote.content
            
            // 只有内容真正改变时才更新
            if hasChanged {
                var note = updatedNote
                note.modifiedAt = Date()
                
                // 只在标题变化或内容有重大改变时才移到顶部
                let shouldMoveToTop = oldNote.title != note.title || 
                                      abs(oldNote.content.count - note.content.count) > 50
                
                if shouldMoveToTop && index > 0 {
                    notes.remove(at: index)
                    notes.insert(note, at: 0)
                } else {
                    notes[index] = note
                }
                
                saveNotes()
            }
        }
    }
    
    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        selectedNotes.remove(note.id)
        saveNotes()
    }
    
    func deleteNotes(_ notesToDelete: [Note]) {
        let idsToDelete = Set(notesToDelete.map { $0.id })
        notes.removeAll { idsToDelete.contains($0.id) }
        selectedNotes.subtract(idsToDelete)
        saveNotes()
    }
    
    func toggleFavorite(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isFavorite.toggle()
            saveNotes()
        }
    }
    
    func addTag(_ tag: String, to note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].tags.insert(tag)
            saveNotes()
        }
    }
    
    func removeTag(_ tag: String, from note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].tags.remove(tag)
            saveNotes()
        }
    }
    
    func toggleSelection(_ note: Note) {
        if selectedNotes.contains(note.id) {
            selectedNotes.remove(note.id)
        } else {
            selectedNotes.insert(note.id)
        }
    }
    
    func selectAll() {
        selectedNotes = Set(filteredNotes.map { $0.id })
    }
    
    func deselectAll() {
        selectedNotes.removeAll()
    }
    
    var filteredNotes: [Note] {
        var filtered = notes
        
        // 搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // 排序
        filtered.sort { first, second in
            // 收藏的笔记总是在前面
            if first.isFavorite && !second.isFavorite {
                return true
            } else if !first.isFavorite && second.isFavorite {
                return false
            }
            
            let result: Bool
            switch sortOption {
            case .modified:
                result = first.modifiedAt > second.modifiedAt
            case .created:
                result = first.createdAt > second.createdAt
            case .title:
                result = first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            case .wordCount:
                result = first.wordCount > second.wordCount
            }
            
            return isAscending ? !result : result
        }
        
        return filtered
    }
    
    var allTags: [String] {
        let allTags = notes.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    func deleteAllNotes() {
        notes.removeAll()
        saveNotes()
    }
    
    private func saveNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            userDefaults.set(data, forKey: notesKey)
            print("NotesManager: 已保存 \(notes.count) 个笔记")
        } catch {
            print("Error saving notes: \(error)")
        }
    }
    
    private func loadNotes() {
        guard let data = userDefaults.data(forKey: notesKey) else {
            // 没有保存的笔记，创建默认样本笔记
            createWelcomeNote()
            print("NotesManager: 创建了默认样本笔记")
            return
        }
        
        do {
            notes = try JSONDecoder().decode([Note].self, from: data)
            print("NotesManager: 加载了 \(notes.count) 个笔记")
            
            // 如果加载的笔记为空，也创建样本笔记
            if notes.isEmpty {
                createWelcomeNote()
                print("NotesManager: 笔记列表为空，创建了默认样本笔记")
            }
        } catch {
            print("Error loading notes: \(error)")
            notes = []
            createWelcomeNote()
            print("NotesManager: 加载失败，创建了默认样本笔记")
        }
    }
    
    private func createWelcomeNote() {
        let welcomeNote = Note(
            title: "Welcome to UnclutterPlus Notes! 🎉",
            content: """
# Welcome to UnclutterPlus Notes! 🎉

欢迎使用 UnclutterPlus 的 **Markdown 笔记功能**！这是一个功能强大的笔记编辑器，支持完整的 Markdown 语法和实时预览。

## ✨ 主要特性

### 📝 强大的编辑功能
- **实时 Markdown 预览** - 支持三种编辑模式
- **语法高亮** - 代码块自动高亮
- **文档大纲** - 自动生成标题导航
- **字数统计** - 实时统计字数和阅读时间

### 🏷️ 智能管理
- **标签系统** - 为笔记添加分类标签
- **收藏功能** - 重要笔记一键收藏置顶
- **全文搜索** - 搜索标题、内容和标签
- **多种排序** - 按时间、标题、字数排序

### 🎨 现代化界面
- **三种布局** - 侧边栏、专注、分屏模式
- **可调节面板** - 拖拽调整窗口比例
- **批量操作** - 多选模式批量管理
- **流畅动画** - 细腻的交互体验

## 🚀 快速开始

### 创建新笔记
点击右上角的 ➕ 按钮，输入标题和标签即可创建新笔记。

### 编辑模式
- **编辑模式** - 纯文本编辑
- **预览模式** - 纯 Markdown 预览  
- **分屏模式** - 编辑和预览并排显示

### 标签管理
为笔记添加标签，便于分类和搜索：
- 在新建笔记时添加标签
- 支持创建新标签
- 点击标签快速筛选

## 📖 Markdown 语法示例

### 文本格式
- **粗体文本** 使用 `**粗体**`
- *斜体文本* 使用 `*斜体*`
- ~~删除线~~ 使用 `~~删除线~~`
- `行内代码` 使用 `` `代码` ``

### 列表
#### 有序列表
1. 第一项
2. 第二项
3. 第三项

#### 无序列表
- 项目 A
- 项目 B
- 项目 C

#### 任务列表
- [x] 已完成的任务
- [x] 另一个已完成任务
- [ ] 待完成任务
- [ ] 另一个待完成任务

### 引用和代码

> 这是一个引用块。
> 
> 可以包含多行内容，非常适合引用重要信息。

```swift
// 代码块示例
func greetUser(name: String) {
    print("Hello, \\(name)! 欢迎使用 UnclutterPlus!")
}

greetUser(name: "Developer")
```

```python
# Python 代码示例
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)

print([fibonacci(i) for i in range(10)])
```

### 链接和表格

创建链接：[UnclutterPlus GitHub](https://github.com/voidzyh/UnclutterPlus)

| 功能 | 支持 | 说明 |
|------|------|------|
| Markdown 渲染 | ✅ | 完整语法支持 |
| 语法高亮 | ✅ | 多种语言 |
| 实时预览 | ✅ | 即时渲染 |
| 标签管理 | ✅ | 分类整理 |

## 💡 使用技巧

1. **快速访问** - 将鼠标移到屏幕顶部边缘，滚轮下滑或双指下滑即可调出窗口
2. **全局快捷键** - 使用 `Cmd+Shift+U` 快速打开/关闭应用
3. **自动保存** - 笔记会自动保存，无需手动保存
4. **大纲导航** - 点击工具栏的大纲按钮，快速跳转到不同章节
5. **拖拽调节** - 可以拖拽调整侧边栏宽度，适应不同使用习惯

## 🎯 下一步

现在你可以：
- 尝试编辑这篇笔记，看看实时预览效果
- 为这篇笔记添加一些标签，比如 `welcome`、`tutorial`
- 创建你的第一篇个人笔记
- 探索不同的编辑模式和布局

---

**享受高效的笔记体验！** 📚✨

*这篇样本笔记展示了 UnclutterPlus Notes 的主要功能，你可以编辑或删除它。*
""",
            tags: ["welcome", "tutorial", "markdown"],
            isFavorite: true
        )
        
        notes = [welcomeNote]
        saveNotes()
    }
}