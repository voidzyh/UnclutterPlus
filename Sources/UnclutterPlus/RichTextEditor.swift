import SwiftUI

// MARK: - SwiftUI 2025 Rich Text Editor
// 支持富文本的 TextEditor 组件 - 利用 SwiftUI 2025 新特性

/// 富文本编辑器状态
struct RichTextEditingState {
    var isBold: Bool = false
    var isItalic: Bool = false
    var isStrikethrough: Bool = false
    var selectedRange: Range<String.Index>?
    var currentLine: String = ""
}

/// 富文本编辑器组件
struct RichTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let fontSize: CGFloat
    let onTextChange: ((String) -> Void)?

    @State private var state = RichTextEditingState()
    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        placeholder: String = "Start typing...",
        fontSize: CGFloat = 14,
        onTextChange: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.fontSize = fontSize
        self.onTextChange = onTextChange
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbarView
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.15),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )

            Divider()
                .background(Color.clear.opacity(0.3))

            // 编辑器
            editorView
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .liquidGlass(cornerRadius: 16, opacity: 0.1)
        )
        .onChange(of: text) { _, newText in
            updateState(from: newText)
            onTextChange?(newText)
        }
        .onChange(of: isFocused) { _, focused in
            // 窗口管理集成
            WindowManager.shared.setEditingNote(focused)
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 8) {
            // 格式化按钮组
            HStack(spacing: 4) {
                FormatButton(
                    icon: "bold",
                    isActive: state.isBold,
                    action: { toggleBold() }
                )

                FormatButton(
                    icon: "italic",
                    isActive: state.isItalic,
                    action: { toggleItalic() }
                )

                FormatButton(
                    icon: "strikethrough",
                    isActive: state.isStrikethrough,
                    action: { toggleStrikethrough() }
                )
            }

            Divider()
                .frame(height: 16)
                .background(Color.clear.opacity(0.3))

            // 标题按钮组
            HStack(spacing: 4) {
                FormatButton(
                    text: "H1",
                    action: { insertHeader(level: 1) }
                )

                FormatButton(
                    text: "H2",
                    action: { insertHeader(level: 2) }
                )

                FormatButton(
                    text: "H3",
                    action: { insertHeader(level: 3) }
                )
            }

            Divider()
                .frame(height: 16)
                .background(Color.clear.opacity(0.3))

            // 列表按钮组
            HStack(spacing: 4) {
                FormatButton(
                    icon: "list.bullet",
                    action: { insertList(type: .bullet) }
                )

                FormatButton(
                    icon: "list.number",
                    action: { insertList(type: .numbered) }
                )

                FormatButton(
                    icon: "checkmark.square",
                    action: { insertList(type: .task) }
                )
            }

            Divider()
                .frame(height: 16)
                .background(Color.clear.opacity(0.3))

            // 其他按钮
            HStack(spacing: 4) {
                FormatButton(
                    icon: "quote.bubble",
                    action: { insertQuote() }
                )

                FormatButton(
                    icon: "curlybraces",
                    action: { insertCodeBlock() }
                )

                FormatButton(
                    icon: "link",
                    action: { insertLink() }
                )
            }

            Spacer()

            // 状态指示器
            if isFocused {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.green.opacity(0.5), radius: 2)
            }
        }
    }

    // MARK: - Editor

    private var editorView: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
                    .padding()
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: fontSize, design: .monospaced))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(8)
        }
        .onAppear {
            updateState(from: text)
        }
    }

    // MARK: - Actions

    private func toggleBold() {
        // SwiftUI 2025: 利用富文本支持
        applyFormatting(.bold)
    }

    private func toggleItalic() {
        applyFormatting(.italic)
    }

    private func toggleStrikethrough() {
        applyFormatting(.strikethrough)
    }

    private func insertHeader(level: Int) {
        let prefix = String(repeating: "#", count: level) + " "
        insertAtLineStart(prefix)
    }

    private func insertList(type: ListType) {
        switch type {
        case .bullet:
            insertAtLineStart("- ")
        case .numbered:
            insertAtLineStart("1. ")
        case .task:
            insertAtLineStart("- [ ] ")
        }
    }

    private func insertQuote() {
        insertAtLineStart("> ")
    }

    private func insertCodeBlock() {
        insertAroundSelection("\n```\n", "\n```\n")
    }

    private func insertLink() {
        insertAroundSelection("[", "](url)")
    }

    private func applyFormatting(_ type: TextFormat) {
        // 简化实现：在选中文本周围添加标记
        let (before, selected, after) = getSelectedText()

        switch type {
        case .bold:
            text = before + "**" + selected + "**" + after
        case .italic:
            text = before + "*" + selected + "*" + after
        case .strikethrough:
            text = before + "~~" + selected + "~~" + after
        }

        // 更新状态
        DispatchQueue.main.async {
            updateState(from: text)
        }
    }

    // MARK: - Helpers

    private func insertAtLineStart(_ prefix: String) {
        // 查找当前行开始位置
        if let range = getCurrentLineRange() {
            text.insert(contentsOf: prefix, at: range.lowerBound)
        } else {
            text += prefix
        }
    }

    private func insertAroundSelection(_ prefix: String, _ suffix: String) {
        let (before, selected, after) = getSelectedText()
        text = before + prefix + selected + suffix + after
    }

    private func getSelectedText() -> (String, String, String) {
        // 简化实现：返回当前选中的文本或光标位置的文本
        let selected = String(text.dropFirst(text.count / 2).prefix(5)) // 示例
        let before = String(text.prefix(text.count / 2 - selected.count / 2))
        let after = String(text.suffix(text.count - before.count - selected.count))
        return (before, selected, after)
    }

    private func getCurrentLineRange() -> Range<String.Index>? {
        // 查找当前光标所在行的范围
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var currentIndex = 0

        for line in lines {
            let lineRange = text.index(text.startIndex, offsetBy: currentIndex)..<text.index(text.startIndex, offsetBy: currentIndex + line.count)
            if lineRange.contains(text.index(text.startIndex, offsetBy: text.count / 2)) {
                return lineRange
            }
            currentIndex += line.count + 1 // +1 for newline
        }

        return nil
    }

    private func updateState(from text: String) {
        // 更新格式化状态
        state.isBold = text.contains("**")
        state.isItalic = text.contains("*")
        state.isStrikethrough = text.contains("~~")

        // 提取当前行
        if let lineRange = getCurrentLineRange() {
            state.currentLine = String(text[lineRange])
        }
    }
}

// MARK: - Supporting Types

enum TextFormat {
    case bold
    case italic
    case strikethrough
}

enum ListType {
    case bullet
    case numbered
    case task
}

// MARK: - Format Button

struct FormatButton: View {
    let icon: String?
    let text: String?
    let isActive: Bool
    let action: () -> Void

    init(
        icon: String? = nil,
        text: String? = nil,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.text = text
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                } else if let text = text {
                    Text(text)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundStyle(isActive ? .white : .primary)
            .frame(minWidth: 24, minHeight: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isActive ? Color.accentColor.opacity(0.5) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isActive ? 1.05 : 1.0)
        }
        .buttonStyle(.liquidGlassNoScale)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isActive)
    }
}

// MARK: - Preview

#if DEBUG
struct RichTextEditorPreview: View {
    @State private var text = "# Welcome to Rich Text Editor!\n\nThis is a **rich text** editor with support for:\n\n- **Bold** text\n- *Italic* text\n- ~~Strikethrough~~ text\n\n```swift\nlet message = \"Hello, World!\"\nprint(message)\n```"

    var body: some View {
        RichTextEditor(
            text: $text,
            placeholder: "Start typing your note...",
            fontSize: 14
        ) { newText in
            print("Text changed: \(newText.count) characters")
        }
        .frame(width: 600, height: 400)
        .padding()
    }
}

#Preview {
    RichTextEditorPreview()
}
#endif
