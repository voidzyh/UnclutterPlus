import SwiftUI

struct ClipboardView: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @State private var searchText = ""
    @State private var selectedItems: Set<UUID> = []
    @State private var hoveredItem: UUID?
    @State private var isMultiSelectMode = false
    @State private var selectedIndex: Int = -1
    
    var filteredItems: [ClipboardItem] {
        var items = clipboardManager.items
        
        // 搜索过滤
        if !searchText.isEmpty {
            items = items.filter { item in
                switch item.content {
                case .text(let text):
                    return text.localizedCaseInsensitiveContains(searchText)
                case .image:
                    return false
                case .file(let url):
                    return url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        // 按置顶和时间排序
        return items.sorted { first, second in
            if first.isPinned && !second.isPinned {
                return true
            } else if !first.isPinned && second.isPinned {
                return false
            } else {
                return first.timestamp > second.timestamp
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search clipboard history...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                
                // 多选模式切换
                Button(action: {
                    isMultiSelectMode.toggle()
                    if !isMultiSelectMode {
                        selectedItems.removeAll()
                    }
                }) {
                    Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(isMultiSelectMode ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(isMultiSelectMode ? "Exit selection mode" : "Enter selection mode")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            if filteredItems.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "No clipboard history" : "No matching items")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "Copy something to see it here" : "Try a different search term")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 剪贴板项目列表
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardItemView(
                                item: item,
                                isSelected: selectedItems.contains(item.id),
                                isHovered: hoveredItem == item.id,
                                showSelectionMode: isMultiSelectMode,
                                indexNumber: index < 9 ? index + 1 : nil
                            ) {
                                // 复制操作
                                copyItem(item)
                            } onDelete: {
                                clipboardManager.removeItem(item)
                            } onTogglePin: {
                                clipboardManager.togglePin(item)
                            } onToggleSelection: {
                                toggleSelection(item)
                            }
                            .onHover { isHovering in
                                hoveredItem = isHovering ? item.id : nil
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // 底部工具栏
            HStack {
                if isMultiSelectMode && !selectedItems.isEmpty {
                    Button("删除已选 (\(selectedItems.count))") {
                        let itemsToRemove = filteredItems.filter { selectedItems.contains($0.id) }
                        clipboardManager.removeItems(itemsToRemove)
                        selectedItems.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                } else {
                    Button("清空全部") {
                        clipboardManager.clearAll()
                        selectedItems.removeAll()
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
                
                Text("\(filteredItems.count) 项目")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isMultiSelectMode {
                    Text("|") 
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("\(selectedItems.count) 已选")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onKeyDown { event in
            handleKeyDown(event)
        }
    }
    
    private func copyItem(_ item: ClipboardItem) {
        clipboardManager.copyToClipboard(item)
        // 显示复制反馈
        withAnimation(.easeInOut(duration: 0.2)) {
            // 可以添加视觉反馈
        }
    }
    
    private func toggleSelection(_ item: ClipboardItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags
        
        // 数字键快速复制（1-9）
        if keyCode >= 18 && keyCode <= 26 && !modifierFlags.contains(.command) {
            let index = Int(keyCode - 18)
            if index < filteredItems.count {
                copyItem(filteredItems[index])
                return true
            }
        }
        
        // Delete 键删除选中项
        if keyCode == 51 { // Delete key
            if !selectedItems.isEmpty {
                let itemsToRemove = filteredItems.filter { selectedItems.contains($0.id) }
                clipboardManager.removeItems(itemsToRemove)
                selectedItems.removeAll()
                return true
            }
        }
        
        // Cmd+A 全选
        if keyCode == 0 && modifierFlags.contains(.command) { // Cmd+A
            if isMultiSelectMode {
                selectedItems = Set(filteredItems.map { $0.id })
                return true
            }
        }
        
        return false
    }
}

struct ClipboardItemView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isHovered: Bool
    let showSelectionMode: Bool
    let indexNumber: Int?
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onToggleSelection: () -> Void
    
    @State private var showFullText = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 选择框/快捷索引
            if showSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            } else if let number = indexNumber {
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .background(.tertiary, in: Circle())
            }
            
            // 类型图标和状态
            VStack(spacing: 2) {
                Image(systemName: item.systemImage)
                    .font(.title2)
                    .foregroundColor(item.typeColor)
                    .frame(width: 24)
                
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            // 内容预览
            VStack(alignment: .leading, spacing: 6) {
                switch item.content {
                case .text(let text):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(showFullText ? text : item.preview)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(showFullText ? nil : 3)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                        
                        if text.count > 100 {
                            Button(showFullText ? "收起" : "展开") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showFullText.toggle()
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                    }
                
                case .image:
                    HStack {
                        Text("图片内容")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                
                case .file(let url):
                    HStack {
                        Text(url.lastPathComponent)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                
                // 时间戳和详情
                HStack {
                    Text(item.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if case .text(let text) = item.content {
                        Spacer()
                        Text("\(text.count) 字符")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮（悬停显示）
            if isHovered || showSelectionMode {
                HStack(spacing: 8) {
                    Button(action: onTogglePin) {
                        Image(systemName: item.isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 14))
                            .foregroundColor(item.isPinned ? .orange : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(item.isPinned ? "取消置顶" : "置顶")
                    
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help("复制到剪贴板")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("删除")
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(16)
        .background(backgroundMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 2)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .onTapGesture {
            if showSelectionMode {
                onToggleSelection()
            } else {
                onCopy()
            }
        }
        .contextMenu {
            Button(item.isPinned ? "取消置顶" : "置顶") {
                onTogglePin()
            }
            
            Divider()
            
            Button("复制") {
                onCopy()
            }
            
            Button("删除", role: .destructive) {
                onDelete()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: showFullText)
    }
    
    private var backgroundMaterial: Material {
        if isSelected {
            return .thick
        } else if item.isPinned {
            return .regularMaterial
        } else {
            return .thinMaterial
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return .accentColor
        } else if item.isPinned {
            return .orange.opacity(0.3)
        } else {
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        if isSelected {
            return 2
        } else if item.isPinned {
            return 1
        } else {
            return 0
        }
    }
    
    private var shadowColor: Color {
        if isSelected {
            return .accentColor.opacity(0.3)
        } else {
            return .black.opacity(0.1)
        }
    }
    
    private var shadowRadius: CGFloat {
        isSelected ? 8 : 4
    }
}

// MARK: - Key Event Handling Extension
extension View {
    func onKeyDown(perform action: @escaping (NSEvent) -> Bool) -> some View {
        self.background(KeyEventHandlingView(onKeyDown: action))
    }
}

struct KeyEventHandlingView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlingNSView()
        view.onKeyDown = onKeyDown
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class KeyHandlingNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if let onKeyDown = onKeyDown, onKeyDown(event) {
            return
        }
        super.keyDown(with: event)
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    ClipboardView()
        .frame(width: 800, height: 250)
}
#endif