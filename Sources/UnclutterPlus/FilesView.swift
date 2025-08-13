import SwiftUI
import UniformTypeIdentifiers

enum ViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
    case grouped = "Grouped"
    
    var systemImage: String {
        switch self {
        case .grid:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        case .grouped:
            return "folder"
        }
    }
}

struct FilesView: View {
    @StateObject private var fileManager = TempFileManager()
    @State private var dragOver = false
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .grid
    @State private var isMultiSelectMode = false
    @State private var hoveredFile: UUID?
    @State private var editingFileName: UUID?
    @State private var newFileName = ""
    
    private var filteredFiles: [TempFile] {
        let files = fileManager.sortedFiles
        
        if searchText.isEmpty {
            return files
        } else {
            return files.filter { file in
                file.name.localizedCaseInsensitiveContains(searchText) ||
                file.fileType.rawValue.localizedCaseInsensitiveContains(searchText) ||
                file.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
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
                    
                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: 200)
                
                Spacer()
                
                // 视图模式切换
                Picker("", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                .labelsHidden()
                
                // 排序选择
                Menu {
                    Section("sort.by".localized) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: { fileManager.sortOption = option }) {
                                HStack {
                                    Text(option.rawValue)
                                    if fileManager.sortOption == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { fileManager.isAscending.toggle() }) {
                        HStack {
                            Text(fileManager.isAscending ? "sort.ascending".localized : "sort.descending".localized)
                            Spacer()
                            Image(systemName: fileManager.isAscending ? "arrow.up" : "arrow.down")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                
                // 多选模式切换
                Button(action: {
                    isMultiSelectMode.toggle()
                    if !isMultiSelectMode {
                        fileManager.deselectAll()
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
            
            if filteredFiles.isEmpty {
                // 空状态
                VStack(spacing: 20) {
                    if searchText.isEmpty {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary)
                        
                        Text("Drop files here")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("Drag and drop files to store them temporarily\nSupports all file types with intelligent categorization")
                            .font(.callout)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No matching files")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("ui.try_different_search".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(dragOver ? Color.accentColor.opacity(0.1) : Color.clear)
                        .stroke(dragOver ? Color.accentColor : Color.gray.opacity(0.3), 
                               lineWidth: dragOver ? 3 : 1)
                        .strokeBorder(style: StrokeStyle(lineWidth: dragOver ? 3 : 1, dash: [10]))
                )
            } else {
                // 文件内容区域
                ScrollView {
                    switch viewMode {
                    case .grid:
                        gridView
                    case .list:
                        listView
                    case .grouped:
                        groupedView
                    }
                }
                .background(
                    Rectangle()
                        .fill(dragOver ? Color.accentColor.opacity(0.05) : Color.clear)
                )
            }
            
            // 底部状态栏
            HStack {
                if isMultiSelectMode && !fileManager.selectedFiles.isEmpty {
                    Button("删除已选 (\(fileManager.selectedFiles.count))") {
                        let selectedFiles = filteredFiles.filter { fileManager.selectedFiles.contains($0.id) }
                        fileManager.removeFiles(selectedFiles)
                        fileManager.deselectAll()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                } else {
                    Button("清空全部") {
                        fileManager.clearAllFiles()
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
                
                Text("\(filteredFiles.count) 文件")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("|") 
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text(ByteCountFormatter.string(fromByteCount: fileManager.totalSize, countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isMultiSelectMode {
                    Text("|") 
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("\(fileManager.selectedFiles.count) 已选")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleFileDrop(providers)
        }
        .onChange(of: dragOver) { _, isDragging in
            WindowManager.shared.setDraggingFile(isDragging)
        }
        .onKeyDown { event in
            handleKeyDown(event)
        }
    }
    
    private var gridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
            ForEach(filteredFiles) { file in
                FileItemGridView(
                    file: file,
                    isSelected: fileManager.selectedFiles.contains(file.id),
                    isHovered: hoveredFile == file.id,
                    showSelectionMode: isMultiSelectMode,
                    isEditing: editingFileName == file.id,
                    editingName: $newFileName
                ) {
                    // 打开文件
                    if isMultiSelectMode {
                        fileManager.toggleSelection(file)
                    } else {
                        fileManager.openFile(file)
                    }
                } onSecondaryAction: {
                    // 显示在Finder中
                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
                } onDelete: {
                    fileManager.removeFile(file)
                } onToggleFavorite: {
                    fileManager.toggleFavorite(file)
                } onToggleSelection: {
                    fileManager.toggleSelection(file)
                } onRename: { newName in
                    fileManager.renameFile(file, to: newName)
                    editingFileName = nil
                } onStartRename: {
                    editingFileName = file.id
                    newFileName = file.name
                }
                .onHover { isHovering in
                    hoveredFile = isHovering ? file.id : nil
                }
            }
        }
        .padding()
    }
    
    private var listView: some View {
        LazyVStack(spacing: 2) {
            ForEach(filteredFiles) { file in
                FileItemListView(
                    file: file,
                    isSelected: fileManager.selectedFiles.contains(file.id),
                    isHovered: hoveredFile == file.id,
                    showSelectionMode: isMultiSelectMode,
                    isEditing: editingFileName == file.id,
                    editingName: $newFileName
                ) {
                    // 打开文件
                    if isMultiSelectMode {
                        fileManager.toggleSelection(file)
                    } else {
                        fileManager.openFile(file)
                    }
                } onSecondaryAction: {
                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
                } onDelete: {
                    fileManager.removeFile(file)
                } onToggleFavorite: {
                    fileManager.toggleFavorite(file)
                } onToggleSelection: {
                    fileManager.toggleSelection(file)
                } onRename: { newName in
                    fileManager.renameFile(file, to: newName)
                    editingFileName = nil
                } onStartRename: {
                    editingFileName = file.id
                    newFileName = file.name
                }
                .onHover { isHovering in
                    hoveredFile = isHovering ? file.id : nil
                }
            }
        }
        .padding()
    }
    
    private var groupedView: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(Array(fileManager.filesByType.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { type in
                if let files = fileManager.filesByType[type], !files.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: type.systemImage)
                                .foregroundColor(type.color)
                                .font(.title2)
                            
                            Text(type.rawValue)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("(\(files.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                            ForEach(files) { file in
                                FileItemGridView(
                                    file: file,
                                    isSelected: fileManager.selectedFiles.contains(file.id),
                                    isHovered: hoveredFile == file.id,
                                    showSelectionMode: isMultiSelectMode,
                                    isEditing: editingFileName == file.id,
                                    editingName: $newFileName
                                ) {
                                    if isMultiSelectMode {
                                        fileManager.toggleSelection(file)
                                    } else {
                                        fileManager.openFile(file)
                                    }
                                } onSecondaryAction: {
                                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
                                } onDelete: {
                                    fileManager.removeFile(file)
                                } onToggleFavorite: {
                                    fileManager.toggleFavorite(file)
                                } onToggleSelection: {
                                    fileManager.toggleSelection(file)
                                } onRename: { newName in
                                    fileManager.renameFile(file, to: newName)
                                    editingFileName = nil
                                } onStartRename: {
                                    editingFileName = file.id
                                    newFileName = file.name
                                }
                                .onHover { isHovering in
                                    hoveredFile = isHovering ? file.id : nil
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding()
    }
    
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags
        
        // Delete 键删除选中文件
        if keyCode == 51 { // Delete key
            if !fileManager.selectedFiles.isEmpty {
                let selectedFiles = filteredFiles.filter { fileManager.selectedFiles.contains($0.id) }
                fileManager.removeFiles(selectedFiles)
                fileManager.deselectAll()
                return true
            }
        }
        
        // Cmd+A 全选
        if keyCode == 0 && modifierFlags.contains(.command) { // Cmd+A
            if isMultiSelectMode {
                fileManager.selectAll()
                return true
            }
        }
        
        return false
    }
    
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        fileManager.addFile(from: url)
                    }
                }
            }
        }
        return true
    }
}

struct FileItemGridView: View {
    let file: TempFile
    let isSelected: Bool
    let isHovered: Bool
    let showSelectionMode: Bool
    let isEditing: Bool
    @Binding var editingName: String
    
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleSelection: () -> Void
    let onRename: (String) -> Void
    let onStartRename: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // 选择框或收藏标记
                if showSelectionMode {
                    VStack {
                        HStack {
                            Button(action: onToggleSelection) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(4)
                } else if file.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .padding(4)
                }
                
                // 文件图标
                VStack(spacing: 8) {
                    Image(systemName: file.systemImage)
                        .font(.system(size: 36))
                        .foregroundColor(file.typeColor)
                    
                    // 文件名
                    if isEditing {
                        TextField("File name", text: $editingName, onCommit: {
                            onRename(editingName)
                        })
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.regularMaterial)
                        )
                    } else {
                        Text(file.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .truncationMode(.middle)
                    }
                    
                    // 文件信息
                    VStack(spacing: 2) {
                        Text(file.sizeString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if !file.tags.isEmpty {
                            HStack {
                                ForEach(Array(file.tags.prefix(2)), id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 8))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(file.typeColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))
                                }
                            }
                        }
                    }
                }
            }
            
            // 悬停操作按钮
            if isHovered && !showSelectionMode && !isEditing {
                HStack(spacing: 8) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: file.isFavorite ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(file.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(file.isFavorite ? "取消收藏" : "收藏")
                    
                    Button(action: onSecondaryAction) {
                        Image(systemName: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("在 Finder 中显示")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("删除")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(12)
        .background(backgroundMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 2)
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .onTapGesture {
            onPrimaryAction()
        }
        .contextMenu {
            Button(file.isFavorite ? "取消收藏" : "收藏") {
                onToggleFavorite()
            }
            
            Divider()
            
            Button("打开") {
                onPrimaryAction()
            }
            
            Button("在 Finder 中显示") {
                onSecondaryAction()
            }
            
            Button("重命名") {
                onStartRename()
            }
            
            Divider()
            
            Button("删除", role: .destructive) {
                onDelete()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var backgroundMaterial: Material {
        if isSelected {
            return .thick
        } else if file.isFavorite {
            return .regularMaterial
        } else {
            return .thinMaterial
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return .accentColor
        } else if file.isFavorite {
            return .yellow.opacity(0.3)
        } else {
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        if isSelected || file.isFavorite {
            return 2
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

struct FileItemListView: View {
    let file: TempFile
    let isSelected: Bool
    let isHovered: Bool
    let showSelectionMode: Bool
    let isEditing: Bool
    @Binding var editingName: String
    
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleSelection: () -> Void
    let onRename: (String) -> Void
    let onStartRename: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 选择框或图标
            if showSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            // 文件图标
            Image(systemName: file.systemImage)
                .font(.title2)
                .foregroundColor(file.typeColor)
                .frame(width: 32)
            
            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if isEditing {
                        TextField("File name", text: $editingName, onCommit: {
                            onRename(editingName)
                        })
                        .textFieldStyle(.plain)
                        .font(.body)
                        .fontWeight(.medium)
                    } else {
                        Text(file.name)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    if file.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Text(file.fileType.rawValue)
                        .font(.caption)
                        .foregroundColor(file.typeColor)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(file.sizeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(file.dateAdded.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                if !file.tags.isEmpty {
                    HStack {
                        ForEach(Array(file.tags), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(file.typeColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮（悬停显示）
            if isHovered || showSelectionMode {
                HStack(spacing: 8) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: file.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(file.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(file.isFavorite ? "取消收藏" : "收藏")
                    
                    Button(action: onSecondaryAction) {
                        Image(systemName: "folder")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("在 Finder 中显示")
                    
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
        .padding(8)
        .background(backgroundMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .onTapGesture {
            onPrimaryAction()
        }
        .contextMenu {
            Button(file.isFavorite ? "取消收藏" : "收藏") {
                onToggleFavorite()
            }
            
            Divider()
            
            Button("打开") {
                onPrimaryAction()
            }
            
            Button("在 Finder 中显示") {
                onSecondaryAction()
            }
            
            Button("重命名") {
                onStartRename()
            }
            
            Divider()
            
            Button("删除", role: .destructive) {
                onDelete()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var backgroundMaterial: Material {
        if isSelected {
            return .thick
        } else {
            return .thinMaterial
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return .accentColor
        } else {
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 1 : 0
    }
}

// Key event handling is already defined in ClipboardView.swift

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    FilesView()
        .frame(width: 800, height: 250)
}
#endif