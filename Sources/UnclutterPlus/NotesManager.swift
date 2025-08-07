import Foundation
import SwiftUI

struct Note: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    let createdAt: Date
    var modifiedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, createdAt, modifiedAt
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
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? "Empty note" : cleaned
    }
    
    init(title: String, content: String = "") {
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

class NotesManager: ObservableObject {
    static let shared = NotesManager()
    
    @Published var notes: [Note] = []
    
    private let userDefaults = UserDefaults.standard
    private let notesKey = "SavedNotes"
    private var hasInitialized = false
    
    private init() {
        print("NotesManager: 初始化 (单例)")
        loadNotes()
        hasInitialized = true
    }
    
    func createNote(title: String) -> Note {
        print("NotesManager: 创建新笔记: \(title)")
        let note = Note(title: title)
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
        saveNotes()
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
        // 尝试加载保存的笔记
        if let data = userDefaults.data(forKey: notesKey) {
            do {
                notes = try JSONDecoder().decode([Note].self, from: data)
                // 按创建时间排序（新的在前）
                notes.sort { $0.createdAt > $1.createdAt }
                print("NotesManager: 加载了 \(notes.count) 个笔记")
            } catch {
                print("Error loading notes: \(error)")
                notes = []
            }
        } else {
            // 没有保存的笔记，保持空列表
            notes = []
            print("NotesManager: 没有找到保存的笔记")
        }
    }
    
    // 不再自动创建示例笔记
    private func createSampleNotes() {
        // 这个方法保留但不使用
        return
        /*
        let sampleNotes = [
            Note(title: "Welcome to UnclutterPlus", content: """
# Welcome to UnclutterPlus Notes! 🎉

This is your **Markdown-powered** note-taking space within UnclutterPlus.

## Features

- ✅ **Full Markdown support** with live preview
- ✅ **Syntax highlighting** for code blocks
- ✅ **Real-time editing** with instant preview
- ✅ **Quick access** from the screen edge

## Getting Started

1. Create new notes with the **+** button
2. Edit notes with **Markdown syntax**  
3. See live preview on the right
4. Notes auto-save as you type

## Markdown Examples

### Text Formatting
- *Italic text*
- **Bold text**
- ~~Strikethrough~~
- `Inline code`

### Code Blocks
```swift
func hello() {
    print("Hello, UnclutterPlus!")
}
```

### Lists & More
- Bullet points
- [x] Task lists
- [x] Completed tasks
- [ ] Todo items

> Blockquotes for important notes

Happy note-taking! 📝
"""),
            
            Note(title: "Quick Markdown Reference", content: """
# Markdown Quick Reference

## Headers
```
# H1 Header
## H2 Header  
### H3 Header
```

## Text Formatting
```
*italic* or _italic_  
**bold** or __bold__
~~strikethrough~~
`inline code`
```

## Lists
```
- Bullet list
- Another item

1. Numbered list
2. Another item

- [x] Task list
- [ ] Unchecked task
```

## Links & Images
```
[Link text](https://example.com)
![Image alt](image-url)
```

## Code Blocks
```
    ```language
    code here
    ```
```

## Other
```  
> Blockquote

---
Horizontal rule
```
"""),
        ]
        
        notes = sampleNotes
        saveNotes()
        */
    }
}