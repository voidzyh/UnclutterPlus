import SwiftUI
import UniformTypeIdentifiers

enum ViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
    
    var systemImage: String {
        switch self {
        case .grid:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        }
    }
}

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    @State private var hoveredFolder: UUID?
    @State private var editingFolderName: UUID?
    @State private var newFolderName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack(spacing: DesignSystem.Spacing.md) {
                // 搜索栏
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .font(DesignSystem.Typography.caption)

                    TextField("folders.search.placeholder".localized, text: $viewModel.searchText)
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
            
            if viewModel.filteredFolders.isEmpty {
                // 空状态
                VStack(spacing: 20) {
                    if viewModel.searchText.isEmpty {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary)
                        
                        Text("folders.drop_area.title".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("folders.drop_area.subtitle".localized)
                            .font(.callout)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("folders.no_matching".localized)
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
                // 文件夹内容区域
                ScrollView {
                    switch viewModel.viewMode {
                    case .grid:
                        gridView
                    case .list:
                        listView
                    }
                }
                .background(
                    Rectangle()
                        .fill(viewModel.dragOver ? Color.accentColor.opacity(0.05) : Color.clear)
                )
            }
            
            // 底部状态栏
            HStack {
                if viewModel.isMultiSelectMode && !viewModel.selectedFolders.isEmpty {
                    Button("folders.delete_selected".localized + " (\(viewModel.selectedFolders.count))") {
                        let selectedFolders = viewModel.filteredFolders.filter { viewModel.selectedFolders.contains($0.id) }
                        viewModel.deleteSelectedFolders(selectedFolders)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                } else {
                    Button("folders.clear_all".localized) {
                        viewModel.clearAllFolders()
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Text("\(viewModel.filteredFolders.count) " + "folders.count".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if viewModel.isMultiSelectMode {
                    Text("|")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("\(viewModel.selectedFolders.count) " + "folders.selected".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onDrop(of: [.fileURL], isTargeted: $viewModel.dragOver) { providers in
            viewModel.handleFolderDrop(providers: providers)
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
            ForEach(viewModel.filteredFolders) { folder in
                folderGridItem(folder)
            }
        }
        .padding()
    }

    private func folderGridItem(_ folder: FavoriteFolder) -> some View {
        FolderItemGridView(
            folder: folder,
            isSelected: viewModel.selectedFolders.contains(folder.id),
            isHovered: hoveredFolder == folder.id,
            showSelectionMode: viewModel.isMultiSelectMode,
            isEditing: editingFolderName == folder.id,
            editingName: $newFolderName
        ) {
            handleFolderTap(folder)
        } onSecondaryAction: {
            viewModel.showInFinder(folder)
        } onDelete: {
            viewModel.deleteFolder(folder)
        } onToggleFavorite: {
            viewModel.toggleFavorite(folder)
        } onToggleSelection: {
            viewModel.toggleSelection(folder)
        } onRename: { newName in
            viewModel.renameFolder(folder, to: newName)
            editingFolderName = nil
        } onStartRename: {
            editingFolderName = folder.id
            newFolderName = folder.name
        } onOpenInNewWindow: {
            viewModel.openFolderInNewWindow(folder)
        } onFileDrop: { providers in
            viewModel.handleFileDragToFolder(providers: providers, folder: folder)
        }
        .onHover { isHovering in
            hoveredFolder = isHovering ? folder.id : nil
        }
    }

    private func handleFolderTap(_ folder: FavoriteFolder) {
        if viewModel.isMultiSelectMode {
            viewModel.toggleSelection(folder)
        } else {
            viewModel.openFolder(folder)
        }
    }
    
    private var listView: some View {
        LazyVStack(spacing: 2) {
            ForEach(viewModel.filteredFolders) { folder in
                folderListItem(folder)
            }
        }
        .padding()
    }

    private func folderListItem(_ folder: FavoriteFolder) -> some View {
        FolderItemListView(
            folder: folder,
            isSelected: viewModel.selectedFolders.contains(folder.id),
            isHovered: hoveredFolder == folder.id,
            showSelectionMode: viewModel.isMultiSelectMode,
            isEditing: editingFolderName == folder.id,
            editingName: $newFolderName
        ) {
            handleFolderTap(folder)
        } onSecondaryAction: {
            viewModel.showInFinder(folder)
        } onDelete: {
            viewModel.deleteFolder(folder)
        } onToggleFavorite: {
            viewModel.toggleFavorite(folder)
        } onToggleSelection: {
            viewModel.toggleSelection(folder)
        } onRename: { newName in
            viewModel.renameFolder(folder, to: newName)
            editingFolderName = nil
        } onStartRename: {
            editingFolderName = folder.id
            newFolderName = folder.name
        } onOpenInNewWindow: {
            viewModel.openFolderInNewWindow(folder)
        } onFileDrop: { providers in
            viewModel.handleFileDragToFolder(providers: providers, folder: folder)
        }
        .onHover { isHovering in
            hoveredFolder = isHovering ? folder.id : nil
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags

        // Delete 键删除选中文件夹
        if keyCode == 51 { // Delete key
            if !viewModel.selectedFolders.isEmpty {
                let selectedFolders = viewModel.filteredFolders.filter { viewModel.selectedFolders.contains($0.id) }
                viewModel.deleteSelectedFolders(selectedFolders)
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
}

struct FolderItemGridView: View {
    let folder: FavoriteFolder
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
    let onOpenInNewWindow: () -> Void
    let onFileDrop: ([NSItemProvider]) -> Bool

    @State private var isDraggingOver = false

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
                } else if folder.isFavorite {
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

                // 文件夹图标和信息
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // 文件夹图标 - 添加微妙动画
                    Image(systemName: folder.systemImage)
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .scaleEffect(isHovered || isDraggingOver ? 1.05 : 1.0)
                        .animation(DesignSystem.Animation.spring, value: isHovered)
                        .animation(DesignSystem.Animation.spring, value: isDraggingOver)

                    // 文件夹名
                    if isEditing {
                        TextField("Folder name", text: $editingName, onCommit: {
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
                        Text(folder.name)
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .truncationMode(.middle)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    // 文件夹信息
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text(folder.itemCountString)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.secondaryText)

                        if !folder.tags.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                ForEach(Array(folder.tags.prefix(2)), id: \.self) { tag in
                                    Text(tag)
                                        .tagStyle(color: .blue)
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
                        icon: folder.isFavorite ? "star.fill" : "star",
                        color: folder.isFavorite ? .yellow : DesignSystem.Colors.secondaryText,
                        action: onToggleFavorite,
                        tooltip: folder.isFavorite ? "folders.contextmenu.unfavorite".localized : "folders.contextmenu.favorite".localized
                    )

                    ActionButton(
                        icon: "arrow.up.forward.square",
                        color: DesignSystem.Colors.secondaryText,
                        action: onOpenInNewWindow,
                        tooltip: "folders.contextmenu.open_new_window".localized
                    )

                    ActionButton(
                        icon: "trash",
                        color: DesignSystem.Colors.error,
                        action: onDelete,
                        tooltip: "folders.contextmenu.delete".localized
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
            Button(folder.isFavorite ? "folders.contextmenu.unfavorite".localized : "folders.contextmenu.favorite".localized) {
                onToggleFavorite()
            }

            Divider()

            Button("folders.contextmenu.open".localized) {
                onPrimaryAction()
            }

            Button("folders.contextmenu.open_new_window".localized) {
                onOpenInNewWindow()
            }

            Button("folders.contextmenu.reveal".localized) {
                onSecondaryAction()
            }

            Button("folders.contextmenu.rename".localized) {
                onStartRename()
            }

            Divider()

            Button("folders.contextmenu.delete".localized, role: .destructive) {
                onDelete()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            onFileDrop(providers)
        }
        .animation(DesignSystem.Animation.spring, value: isHovered)
        .animation(DesignSystem.Animation.standard, value: isSelected)
    }

    private var backgroundMaterial: Material {
        if isSelected {
            return .thick
        } else if folder.isFavorite {
            return .regularMaterial
        } else {
            return .thinMaterial
        }
    }

    private var borderColor: Color {
        if isDraggingOver {
            return DesignSystem.Colors.accent
        } else if isSelected {
            return DesignSystem.Colors.accent
        } else if isHovered {
            return DesignSystem.Colors.accent.opacity(0.3)
        } else if folder.isFavorite {
            return Color.yellow.opacity(0.3)
        } else {
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        if isDraggingOver {
            return 3
        } else if isSelected {
            return 2
        } else if isHovered || folder.isFavorite {
            return 1.5
        } else {
            return 0
        }
    }

    private var shadowColor: Color {
        if isDraggingOver {
            return DesignSystem.Colors.accent.opacity(0.4)
        } else if isSelected {
            return DesignSystem.Colors.accent.opacity(0.3)
        } else if isHovered {
            return .black.opacity(0.15)
        } else {
            return .black.opacity(0.08)
        }
    }

    private var shadowRadius: CGFloat {
        if isDraggingOver {
            return 12
        } else if isSelected {
            return 10
        } else if isHovered {
            return 12
        } else {
            return 4
        }
    }

    private var shadowOffset: CGFloat {
        if isHovered || isDraggingOver {
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

struct FolderItemListView: View {
    let folder: FavoriteFolder
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
    let onOpenInNewWindow: () -> Void
    let onFileDrop: ([NSItemProvider]) -> Bool

    @State private var isDraggingOver = false

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

            // 文件夹图标
            Image(systemName: folder.systemImage)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 32)
                .scaleEffect(isHovered || isDraggingOver ? 1.05 : 1.0)
                .animation(DesignSystem.Animation.spring, value: isHovered)
                .animation(DesignSystem.Animation.spring, value: isDraggingOver)

            // 文件夹信息
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if isEditing {
                        TextField("Folder name", text: $editingName, onCommit: {
                            onRename(editingName)
                        })
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                    } else {
                        Text(folder.name)
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    if folder.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(DesignSystem.Typography.caption)
                    }

                    Spacer()
                }

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(folder.itemCountString)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Text("•")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Text(folder.dateAdded.formatted(.relative(presentation: .named)))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Spacer()
                }

                if !folder.tags.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(Array(folder.tags), id: \.self) { tag in
                            Text(tag)
                                .tagStyle(color: .blue)
                        }
                    }
                }
            }

            Spacer()

            // 操作按钮（悬停显示）
            if isHovered || showSelectionMode {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ActionButton(
                        icon: folder.isFavorite ? "star.fill" : "star",
                        color: folder.isFavorite ? .yellow : DesignSystem.Colors.secondaryText,
                        action: onToggleFavorite,
                        tooltip: folder.isFavorite ? "folders.contextmenu.unfavorite".localized : "folders.contextmenu.favorite".localized
                    )

                    ActionButton(
                        icon: "arrow.up.forward.square",
                        color: DesignSystem.Colors.secondaryText,
                        action: onOpenInNewWindow,
                        tooltip: "folders.contextmenu.open_new_window".localized
                    )

                    ActionButton(
                        icon: "trash",
                        color: DesignSystem.Colors.error,
                        action: onDelete,
                        tooltip: "folders.contextmenu.delete".localized
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
            Button(folder.isFavorite ? "folders.contextmenu.unfavorite".localized : "folders.contextmenu.favorite".localized) {
                onToggleFavorite()
            }

            Divider()

            Button("folders.contextmenu.open".localized) {
                onPrimaryAction()
            }

            Button("folders.contextmenu.open_new_window".localized) {
                onOpenInNewWindow()
            }

            Button("folders.contextmenu.reveal".localized) {
                onSecondaryAction()
            }

            Button("folders.contextmenu.rename".localized) {
                onStartRename()
            }

            Divider()

            Button("folders.contextmenu.delete".localized, role: .destructive) {
                onDelete()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            onFileDrop(providers)
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
        if isDraggingOver {
            return DesignSystem.Colors.accent
        } else if isSelected {
            return DesignSystem.Colors.accent
        } else if isHovered {
            return DesignSystem.Colors.accent.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        if isDraggingOver {
            return 3
        } else if isSelected {
            return 2
        } else if isHovered {
            return 1
        } else {
            return 0
        }
    }

    private var shadowColor: Color {
        if isDraggingOver {
            return DesignSystem.Colors.accent.opacity(0.3)
        } else if isSelected {
            return DesignSystem.Colors.accent.opacity(0.2)
        } else if isHovered {
            return .black.opacity(0.08)
        } else {
            return .black.opacity(0.03)
        }
    }

    private var shadowRadius: CGFloat {
        if isHovered || isSelected || isDraggingOver {
            return 4
        } else {
            return 2
        }
    }

    private var shadowOffset: CGFloat {
        if isHovered || isSelected || isDraggingOver {
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

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    FilesView()
        .frame(width: 800, height: 250)
}
#endif
