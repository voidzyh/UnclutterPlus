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
            HStack(spacing: DesignSystem.Spacing.md) {
                // 搜索栏
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .font(DesignSystem.Typography.caption)

                    TextField("Search files...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)

                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.clearSearch() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .font(DesignSystem.Typography.caption)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm + 2)
                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small + 2))
                .frame(maxWidth: 200)

                Spacer()

                // 视图模式切换
                ViewModePicker(selection: $viewModel.viewMode)

                // 排序选择
                SortMenuButton(
                    sortOption: viewModel.sortOption,
                    isAscending: viewModel.isAscending,
                    onSelectOption: { viewModel.setSortOption($0) },
                    onToggleOrder: { viewModel.toggleSortOrder() }
                )

                // 多选模式切换
                MultiSelectButton(
                    isActive: viewModel.isMultiSelectMode,
                    action: { viewModel.toggleMultiSelectMode() }
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)
            
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
        VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                // 选择框或收藏标记
                if showSelectionMode {
                    VStack {
                        HStack {
                            Button(action: onToggleSelection) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                                    .font(DesignSystem.Typography.title3)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.xs)
                } else if file.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(DesignSystem.Typography.caption)
                        }
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.xs)
                }

                // 文件图标和信息
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // 文件图标 - 添加微妙动画
                    Image(systemName: file.systemImage)
                        .font(.system(size: 40))
                        .foregroundColor(file.typeColor)
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                        .animation(DesignSystem.Animation.spring, value: isHovered)

                    // 文件名
                    if isEditing {
                        TextField("File name", text: $editingName, onCommit: {
                            onRename(editingName)
                        })
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.caption)
                        .multilineTextAlignment(.center)
                        .padding(DesignSystem.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(.regularMaterial)
                        )
                    } else {
                        Text(file.name)
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .truncationMode(.middle)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    // 文件信息
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text(file.sizeString)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.secondaryText)

                        if !file.tags.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                ForEach(Array(file.tags.prefix(2)), id: \.self) { tag in
                                    Text(tag)
                                        .tagStyle(color: file.typeColor)
                                }
                            }
                        }
                    }
                }
            }

            // 悬停操作按钮 - 改进动画
            if isHovered && !showSelectionMode && !isEditing {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ActionButton(
                        icon: file.isFavorite ? "star.fill" : "star",
                        color: file.isFavorite ? .yellow : DesignSystem.Colors.secondaryText,
                        action: onToggleFavorite,
                        tooltip: file.isFavorite ? "取消收藏" : "收藏"
                    )

                    ActionButton(
                        icon: "folder",
                        color: DesignSystem.Colors.secondaryText,
                        action: onSecondaryAction,
                        tooltip: "在 Finder 中显示"
                    )

                    ActionButton(
                        icon: "trash",
                        color: DesignSystem.Colors.error,
                        action: onDelete,
                        tooltip: "删除"
                    )
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(minWidth: DesignSystem.Size.cardMinWidth, minHeight: DesignSystem.Size.cardMinHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(backgroundMaterial)
                .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .scaleEffect(isHovered ? 1.03 : (isSelected ? 0.98 : 1.0))
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
        .animation(DesignSystem.Animation.spring, value: isHovered)
        .animation(DesignSystem.Animation.standard, value: isSelected)
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
            return DesignSystem.Colors.accent
        } else if isHovered {
            return DesignSystem.Colors.accent.opacity(0.3)
        } else if file.isFavorite {
            return Color.yellow.opacity(0.3)
        } else {
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        if isSelected {
            return 2
        } else if isHovered || file.isFavorite {
            return 1.5
        } else {
            return 0
        }
    }

    private var shadowColor: Color {
        if isSelected {
            return DesignSystem.Colors.accent.opacity(0.3)
        } else if isHovered {
            return .black.opacity(0.15)
        } else {
            return .black.opacity(0.08)
        }
    }

    private var shadowRadius: CGFloat {
        if isSelected {
            return 10
        } else if isHovered {
            return 12
        } else {
            return 4
        }
    }

    private var shadowOffset: CGFloat {
        if isHovered {
            return 6
        } else if isSelected {
            return 4
        } else {
            return 2
        }
    }
}

// MARK: - Action Button Component
private struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    let tooltip: String

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isHovered ? color.opacity(0.15) : Color.clear)
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.fast) {
                isHovered = hovering
            }
        }
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
        HStack(spacing: DesignSystem.Spacing.md) {
            // 选择框或图标
            if showSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                        .font(DesignSystem.Typography.title3)
                }
                .buttonStyle(.plain)
            }

            // 文件图标
            Image(systemName: file.systemImage)
                .font(.system(size: 24))
                .foregroundColor(file.typeColor)
                .frame(width: 32)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(DesignSystem.Animation.spring, value: isHovered)

            // 文件信息
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if isEditing {
                        TextField("File name", text: $editingName, onCommit: {
                            onRename(editingName)
                        })
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                    } else {
                        Text(file.name)
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    if file.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(DesignSystem.Typography.caption)
                    }

                    Spacer()
                }

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(file.fileType.rawValue)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(file.typeColor)

                    Text("•")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Text(file.sizeString)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Text("•")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Text(file.dateAdded.formatted(.relative(presentation: .named)))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Spacer()
                }

                if !file.tags.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(Array(file.tags), id: \.self) { tag in
                            Text(tag)
                                .tagStyle(color: file.typeColor)
                        }
                    }
                }
            }

            Spacer()

            // 操作按钮（悬停显示）
            if isHovered || showSelectionMode {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ActionButton(
                        icon: file.isFavorite ? "star.fill" : "star",
                        color: file.isFavorite ? .yellow : DesignSystem.Colors.secondaryText,
                        action: onToggleFavorite,
                        tooltip: file.isFavorite ? "取消收藏" : "收藏"
                    )

                    ActionButton(
                        icon: "folder",
                        color: DesignSystem.Colors.secondaryText,
                        action: onSecondaryAction,
                        tooltip: "在 Finder 中显示"
                    )

                    ActionButton(
                        icon: "trash",
                        color: DesignSystem.Colors.error,
                        action: onDelete,
                        tooltip: "删除"
                    )
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(backgroundMaterial)
                .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .scaleEffect(isHovered ? 1.005 : 1.0, anchor: .leading)
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
        .animation(DesignSystem.Animation.spring, value: isHovered)
        .animation(DesignSystem.Animation.standard, value: isSelected)
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
            return DesignSystem.Colors.accent
        } else if isHovered {
            return DesignSystem.Colors.accent.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        if isSelected {
            return 2
        } else if isHovered {
            return 1
        } else {
            return 0
        }
    }

    private var shadowColor: Color {
        if isSelected {
            return DesignSystem.Colors.accent.opacity(0.2)
        } else if isHovered {
            return .black.opacity(0.08)
        } else {
            return .black.opacity(0.03)
        }
    }

    private var shadowRadius: CGFloat {
        if isHovered || isSelected {
            return 4
        } else {
            return 2
        }
    }

    private var shadowOffset: CGFloat {
        if isHovered || isSelected {
            return 2
        } else {
            return 1
        }
    }
}

// MARK: - 工具栏组件

/// 视图模式选择器
struct ViewModePicker: View {
    @Binding var selection: ViewMode
    @State private var hoveredMode: ViewMode?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(DesignSystem.Animation.spring) {
                        selection = mode
                    }
                }) {
                    Image(systemName: mode.systemImage)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(foregroundColor(for: mode))
                        .frame(width: 32, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(backgroundColor(for: mode))
                        )
                        .scaleEffect(scaleEffect(for: mode))
                        .animation(DesignSystem.Animation.spring, value: hoveredMode)
                        .animation(DesignSystem.Animation.spring, value: selection)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredMode = hovering ? mode : nil
                }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small + 2)
                .fill(.regularMaterial)
        )
    }

    private func foregroundColor(for mode: ViewMode) -> Color {
        if selection == mode {
            return .white
        } else if hoveredMode == mode {
            return DesignSystem.Colors.primaryText
        } else {
            return DesignSystem.Colors.secondaryText
        }
    }

    private func backgroundColor(for mode: ViewMode) -> Color {
        if selection == mode {
            return DesignSystem.Colors.accent
        } else if hoveredMode == mode {
            return DesignSystem.Colors.primaryText.opacity(0.1)
        } else {
            return .clear
        }
    }

    private func scaleEffect(for mode: ViewMode) -> CGFloat {
        hoveredMode == mode && selection != mode ? 1.05 : 1.0
    }
}

/// 排序菜单按钮
struct SortMenuButton: View {
    let sortOption: SortOption
    let isAscending: Bool
    let onSelectOption: (SortOption) -> Void
    let onToggleOrder: () -> Void

    @State private var isHovered = false

    var body: some View {
        Menu {
            Section("sort.by".localized) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: { onSelectOption(option) }) {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Button(action: onToggleOrder) {
                HStack {
                    Text(isAscending ? "sort.ascending".localized : "sort.descending".localized)
                    Spacer()
                    Image(systemName: isAscending ? "arrow.up" : "arrow.down")
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(DesignSystem.Typography.body)
                .foregroundColor(isHovered ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isHovered ? DesignSystem.Colors.primaryText.opacity(0.1) : .clear)
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(DesignSystem.Animation.spring, value: isHovered)
        }
        .menuStyle(.borderlessButton)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// 多选模式按钮
struct MultiSelectButton: View {
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "checkmark.circle")
                .font(DesignSystem.Typography.body)
                .foregroundColor(foregroundColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )
                .scaleEffect(scaleEffect)
                .animation(DesignSystem.Animation.spring, value: isHovered)
                .animation(DesignSystem.Animation.spring, value: isActive)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(isActive ? "Exit selection mode" : "Enter selection mode")
    }

    private var foregroundColor: Color {
        if isActive {
            return DesignSystem.Colors.accent
        } else if isHovered {
            return DesignSystem.Colors.primaryText
        } else {
            return DesignSystem.Colors.secondaryText
        }
    }

    private var backgroundColor: Color {
        isHovered && !isActive ? DesignSystem.Colors.primaryText.opacity(0.1) : .clear
    }

    private var scaleEffect: CGFloat {
        isActive ? 1.0 : (isHovered ? 1.1 : 1.0)
    }
}

// Key event handling is already defined in ClipboardView.swift

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    FilesView()
        .frame(width: 800, height: 250)
}
#endif