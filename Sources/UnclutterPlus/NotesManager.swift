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
    @Published var notes: [Note] = []
    
    private let userDefaults = UserDefaults.standard
    private let notesKey = "SavedNotes"
    
    init() {
        print("NotesManager: 初始化")
        loadNotes()
        print("NotesManager: 已加载 \(notes.count) 个笔记")
    }
    
    func createNote(title: String) -> Note {
        print("NotesManager: 创建新笔记: \(title)")
        let note = Note(title: title)
        notes.insert(note, at: 0)
        saveNotes()
        print("NotesManager: 现有 \(notes.count) 个笔记")
        return note
    }
    
    func updateNote(_ updatedNote: Note) {
        if let index = notes.firstIndex(where: { $0.id == updatedNote.id }) {
            var note = updatedNote
            note.modifiedAt = Date()
            notes[index] = note
            
            // 将更新的笔记移到顶部
            notes.remove(at: index)
            notes.insert(note, at: 0)
            
            saveNotes()
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
        guard let data = userDefaults.data(forKey: notesKey) else {
            // 如果没有保存的笔记，创建一些示例笔记
            createSampleNotes()
            return
        }
        
        do {
            notes = try JSONDecoder().decode([Note].self, from: data)
            // 按修改时间排序
            notes.sort { $0.modifiedAt > $1.modifiedAt }
        } catch {
            print("Error loading notes: \(error)")
            createSampleNotes()
        }
    }
    
    private func createSampleNotes() {
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
    }
}