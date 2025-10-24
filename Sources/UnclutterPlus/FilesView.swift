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
    @StateObject private var viewModel = FilesViewModel()
    @State private var hoveredFile: UUID?
    @State private var editingFileName: UUID?
    @State private var newFileName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search files...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)

                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.clearSearch() }) {
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
                Picker("", selection: $viewModel.viewMode) {
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
                            Button(action: { viewModel.setSortOption(option) }) {
                                HStack {
                                    Text(option.rawValue)
                                    if viewModel.sortOption == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Button(action: { viewModel.toggleSortOrder() }) {
                        HStack {
                            Text(viewModel.isAscending ? "sort.ascending".localized : "sort.descending".localized)
                            Spacer()
                            Image(systemName: viewModel.isAscending ? "arrow.up" : "arrow.down")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                
                // 多选模式切换
                Button(action: {
                    viewModel.toggleMultiSelectMode()
                }) {
                    Image(systemName: viewModel.isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(viewModel.isMultiSelectMode ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(viewModel.isMultiSelectMode ? "Exit selection mode" : "Enter selection mode")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            if viewModel.filteredFiles.isEmpty {
                // 空状态
                VStack(spacing: 20) {
                    if viewModel.searchText.isEmpty {
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
                        .fill(viewModel.dragOver ? Color.accentColor.opacity(0.1) : Color.clear)
                        .stroke(viewModel.dragOver ? Color.accentColor : Color.gray.opacity(0.3),
                               lineWidth: viewModel.dragOver ? 3 : 1)
                        .strokeBorder(style: StrokeStyle(lineWidth: viewModel.dragOver ? 3 : 1, dash: [10]))
                )
            } else {
                // 文件内容区域
                ScrollView {
                    switch viewModel.viewMode {
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
                        .fill(viewModel.dragOver ? Color.accentColor.opacity(0.05) : Color.clear)
                )
            }
            
            // 底部状态栏
            HStack {
                if viewModel.isMultiSelectMode && !viewModel.selectedFiles.isEmpty {
                    Button("删除已选 (\(viewModel.selectedFiles.count))") {
                        let selectedFiles = viewModel.filteredFiles.filter { viewModel.selectedFiles.contains($0.id) }
                        viewModel.deleteSelectedFiles(selectedFiles)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                } else {
                    Button("清空全部") {
                        viewModel.clearAllFiles()
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Text("\(viewModel.filteredFiles.count) 文件")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("|")
                    .foregroundColor(.secondary)
                    .font(.caption)

                Text(ByteCountFormatter.string(fromByteCount: viewModel.totalSize, countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if viewModel.isMultiSelectMode {
                    Text("|")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("\(viewModel.selectedFiles.count) 已选")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onDrop(of: [.fileURL], isTargeted: $viewModel.dragOver) { providers in
            viewModel.handleFileDrop(providers: providers)
        }
        .onChange(of: viewModel.dragOver) { _, isDragging in
            WindowManager.shared.setDraggingFile(isDragging)
        }
        .onKeyDown { event in
            handleKeyDown(event)
        }
    }
    
    private var gridView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.filteredFiles) { file in
                fileGridItem(file)
            }
        }
        .padding()
    }

    private func fileGridItem(_ file: TempFile) -> some View {
        FileItemGridView(
            file: file,
            isSelected: viewModel.selectedFiles.contains(file.id),
            isHovered: hoveredFile == file.id,
            showSelectionMode: viewModel.isMultiSelectMode,
            isEditing: editingFileName == file.id,
            editingName: $newFileName
        ) {
            handleFileTap(file)
        } onSecondaryAction: {
            viewModel.showInFinder(file)
        } onDelete: {
            viewModel.deleteFile(file)
        } onToggleFavorite: {
            viewModel.toggleFavorite(file)
        } onToggleSelection: {
            viewModel.toggleSelection(file)
        } onRename: { newName in
            viewModel.renameFile(file, to: newName)
            editingFileName = nil
        } onStartRename: {
            editingFileName = file.id
            newFileName = file.name
        }
        .onHover { isHovering in
            hoveredFile = isHovering ? file.id : nil
        }
    }

    private func handleFileTap(_ file: TempFile) {
        if viewModel.isMultiSelectMode {
            viewModel.toggleSelection(file)
        } else {
            viewModel.openFile(file)
        }
    }
    
    private var listView: some View {
        LazyVStack(spacing: 2) {
            ForEach(viewModel.filteredFiles) { file in
                fileListItem(file)
            }
        }
        .padding()
    }

    private func fileListItem(_ file: TempFile) -> some View {
        FileItemListView(
            file: file,
            isSelected: viewModel.selectedFiles.contains(file.id),
            isHovered: hoveredFile == file.id,
            showSelectionMode: viewModel.isMultiSelectMode,
            isEditing: editingFileName == file.id,
            editingName: $newFileName
        ) {
            handleFileTap(file)
        } onSecondaryAction: {
            viewModel.showInFinder(file)
        } onDelete: {
            viewModel.deleteFile(file)
        } onToggleFavorite: {
            viewModel.toggleFavorite(file)
        } onToggleSelection: {
            viewModel.toggleSelection(file)
        } onRename: { newName in
            viewModel.renameFile(file, to: newName)
            editingFileName = nil
        } onStartRename: {
            editingFileName = file.id
            newFileName = file.name
        }
        .onHover { isHovering in
            hoveredFile = isHovering ? file.id : nil
        }
    }

    private var groupedView: some View {
        let sortedTypes = Array(viewModel.filesByType.keys.sorted(by: { $0.rawValue < $1.rawValue }))
        return LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(sortedTypes, id: \.self) { type in
                fileTypeGroup(type)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func fileTypeGroup(_ type: FileType) -> some View {
        if let files = viewModel.filesByType[type], !files.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                fileTypeHeader(type, count: files.count)
                fileTypeGrid(files)
            }
        }
    }

    private func fileTypeHeader(_ type: FileType, count: Int) -> some View {
        HStack {
            Image(systemName: type.systemImage)
                .foregroundColor(type.color)
                .font(.title2)

            Text(type.rawValue)
                .font(.headline)
                .fontWeight(.semibold)

            Text("(\(count))")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal)
    }

    private func fileTypeGrid(_ files: [TempFile]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(files) { file in
                fileGridItem(file)
            }
        }
        .padding(.horizontal)
    }
    
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags

        // Delete 键删除选中文件
        if keyCode == 51 { // Delete key
            if !viewModel.selectedFiles.isEmpty {
                let selectedFiles = viewModel.filteredFiles.filter { viewModel.selectedFiles.contains($0.id) }
                viewModel.deleteSelectedFiles(selectedFiles)
                return true
            }
        }

        // Cmd+A 全选
        if keyCode == 0 && modifierFlags.contains(.command) { // Cmd+A
            if viewModel.isMultiSelectMode {
                viewModel.selectAll()
                return true
            }
        }

        return false
    }

    // 删除 handleFileDrop 函数,因为已由 ViewModel 处理
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