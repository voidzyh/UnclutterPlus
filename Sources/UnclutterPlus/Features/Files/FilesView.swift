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
            toolbarView
            
            // 主内容区域
            if viewModel.filteredFolders.isEmpty {
                emptyStateView
            } else {
                contentAreaView
            }
            
            // 底部状态栏
            statusBarView
        }
        .onDrop(of: [.fileURL], isTargeted: $viewModel.dragOver) { providers in
            viewModel.handleFolderDrop(providers: providers)
        }
        .onChange(of: viewModel.dragOver) { _, isDragging in
            WindowManager.shared.setDraggingFile(isDragging)
        }
    }
    
    // MARK: - Extracted Subviews
    
    private var toolbarView: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            searchBarView
            
            Spacer()
            
            viewModePickerView
            
            sortMenuButtonView
            
            multiSelectButtonView
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.md)
    }
    
    private var searchBarView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .font(DesignSystem.Typography.caption)
            
            TextField("folders.search.placeholder".localized, text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
            
            if !viewModel.searchText.isEmpty {
                clearSearchButton
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm + 2)
        .padding(.vertical, DesignSystem.Spacing.xs + 2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small + 2))
        .frame(maxWidth: 200)
    }
    
    private var clearSearchButton: some View {
        Button(action: { viewModel.clearSearch() }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .font(DesignSystem.Typography.caption)
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
    
    private var viewModePickerView: some View {
        ViewModePicker(selection: $viewModel.viewMode)
    }
    
    private var sortMenuButtonView: some View {
        SortMenuButton(
            sortOption: viewModel.sortOption,
            isAscending: viewModel.isAscending,
            onSelectOption: { viewModel.setSortOption($0) },
            onToggleOrder: { viewModel.toggleSortOrder() }
        )
    }
    
    private var multiSelectButtonView: some View {
        MultiSelectButton(
            isActive: viewModel.isMultiSelectMode,
            action: { viewModel.toggleMultiSelectMode() }
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if viewModel.searchText.isEmpty {
                emptyFoldersView
            } else {
                noSearchResultsView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(emptyStateBackground)
    }
    
    private var emptyFoldersView: some View {
        Group {
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
        }
    }
    
    private var noSearchResultsView: some View {
        Group {
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
    
    private var emptyStateBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(viewModel.dragOver ? Color.accentColor.opacity(0.1) : Color.clear)
            .stroke(viewModel.dragOver ? Color.accentColor : Color.gray.opacity(0.3),
                   lineWidth: viewModel.dragOver ? 3 : 1)
            .strokeBorder(style: StrokeStyle(lineWidth: viewModel.dragOver ? 3 : 1, dash: [10]))
    }
    
    private var contentAreaView: some View {
        ScrollView {
            foldersContentView
        }
        .background(
            Rectangle()
                .fill(viewModel.dragOver ? Color.accentColor.opacity(0.05) : Color.clear)
        )
    }
    
    private var foldersContentView: some View {
        Group {
            switch viewModel.viewMode {
            case .grid:
                gridView
            case .list:
                listView
            }
        }
    }
    
    private var statusBarView: some View {
        HStack {
            if viewModel.isMultiSelectMode && !viewModel.selectedFolders.isEmpty {
                deleteSelectedButton
            } else {
                clearAllButton
            }
            
            Spacer()
            
            foldersCountView
            
            if viewModel.isMultiSelectMode {
                selectedCountView
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    private var deleteSelectedButton: some View {
        Button("folders.delete_selected".localized + " (\(viewModel.selectedFolders.count))") {
            let selectedFolders = viewModel.filteredFolders.filter { viewModel.selectedFolders.contains($0.id) }
            viewModel.deleteSelectedFolders(selectedFolders)
        }
        .buttonStyle(.borderless)
        .foregroundColor(.red)
    }
    
    private var clearAllButton: some View {
        Button("folders.clear_all".localized) {
            viewModel.clearAllFolders()
        }
        .buttonStyle(.borderless)
    }
    
    private var foldersCountView: some View {
        Text("\(viewModel.filteredFolders.count) " + "folders.count".localized)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var selectedCountView: some View {
        Group {
            Text("|")
                .foregroundColor(.secondary)
                .font(.caption)
            Text("\(viewModel.selectedFolders.count) " + "folders.selected".localized)
                .font(.caption)
                .foregroundColor(.secondary)
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
            contentStack
            
            if isHovered && !showSelectionMode && !isEditing {
                actionButtonsView
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(minWidth: DesignSystem.Size.cardMinWidth, minHeight: DesignSystem.Size.cardMinHeight)
        .background(cardBackground)
        .overlay(cardBorder)
        .scaleEffect(isHovered ? 1.03 : (isSelected ? 0.98 : 1.0))
        .onTapGesture {
            onPrimaryAction()
        }
        .contextMenu {
            contextMenuContent
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            onFileDrop(providers)
        }
        .animation(DesignSystem.Animation.spring, value: isHovered)
        .animation(DesignSystem.Animation.standard, value: isSelected)
    }
    
    // MARK: - Extracted Subviews
    
    private var contentStack: some View {
        ZStack {
            overlayContent
            
            folderInfoStack
        }
    }
    
    private var overlayContent: some View {
        Group {
            if showSelectionMode {
                selectionOverlay
            } else if folder.isFavorite {
                favoriteOverlay
            }
        }
    }
    
    private var selectionOverlay: some View {
        VStack {
            HStack {
                selectionButton
                Spacer()
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.xs)
    }
    
    private var favoriteOverlay: some View {
        VStack {
            HStack {
                Spacer()
                favoriteIcon
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.xs)
    }
    
    private var selectionButton: some View {
        Button(action: onToggleSelection) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                .font(DesignSystem.Typography.title3)
        }
        .buttonStyle(.plain)
    }
    
    private var favoriteIcon: some View {
        Image(systemName: "star.fill")
            .foregroundColor(.yellow)
            .font(DesignSystem.Typography.caption)
    }
    
    private var folderInfoStack: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            folderIcon
            
            if isEditing {
                editingNameField
            } else {
                folderNameText
            }
            
            folderInfoSection
        }
    }
    
    private var folderIcon: some View {
        Image(systemName: folder.customIcon ?? "folder")
            .font(.system(size: 40))
            .foregroundColor(.blue)
            .scaleEffect(isHovered || isDraggingOver ? 1.05 : 1.0)
            .animation(DesignSystem.Animation.spring, value: isHovered)
            .animation(DesignSystem.Animation.spring, value: isDraggingOver)
    }
    
    private var editingNameField: some View {
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
    }
    
    private var folderNameText: some View {
        Text(folder.name)
            .font(DesignSystem.Typography.caption)
            .fontWeight(.medium)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .truncationMode(.middle)
            .foregroundColor(DesignSystem.Colors.primaryText)
    }
    
    private var folderInfoSection: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            itemCountText
            
            if !folder.tags.isEmpty {
                tagsView
            }
        }
    }
    
    private var itemCountText: some View {
        Text(folder.itemCountString)
            .font(DesignSystem.Typography.caption2)
            .foregroundColor(DesignSystem.Colors.secondaryText)
    }
    
    private var tagsView: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(Array(folder.tags.prefix(2)), id: \.self) { tag in
                Text(tag)
                    .tagStyle(color: .blue)
            }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            favoriteActionButton
            
            openNewWindowButton
            
            deleteActionButton
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(actionButtonsBackground)
        .transition(actionButtonsTransition)
    }
    
    private var favoriteActionButton: some View {
        ActionButton(
            icon: folder.isFavorite ? "star.fill" : "star",
            color: folder.isFavorite ? .yellow : DesignSystem.Colors.secondaryText,
            action: onToggleFavorite,
            tooltip: folder.isFavorite ? "folders.contextmenu.unfavorite".localized : "folders.contextmenu.favorite".localized
        )
    }
    
    private var openNewWindowButton: some View {
        ActionButton(
            icon: "arrow.up.forward.square",
            color: DesignSystem.Colors.secondaryText,
            action: onOpenInNewWindow,
            tooltip: "folders.contextmenu.open_new_window".localized
        )
    }
    
    private var deleteActionButton: some View {
        ActionButton(
            icon: "trash",
            color: DesignSystem.Colors.error,
            action: onDelete,
            tooltip: "folders.contextmenu.delete".localized
        )
    }
    
    private var actionButtonsBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var actionButtonsTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        )
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
            .fill(backgroundMaterial)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }
    
    private var contextMenuContent: some View {
        Group {
            favoriteContextMenuButton
            
            Divider()
            
            openContextMenuButton
            openNewWindowContextMenuButton
            revealContextMenuButton
            renameContextMenuButton
            
            Divider()
            
            deleteContextMenuButton
        }
    }
    
    private var favoriteContextMenuButton: some View {
        Button(folder.isFavorite ? "folders.contextmenu.unfavorite".localized : "folders.contextmenu.favorite".localized) {
            onToggleFavorite()
        }
    }
    
    private var openContextMenuButton: some View {
        Button("folders.contextmenu.open".localized) {
            onPrimaryAction()
        }
    }
    
    private var openNewWindowContextMenuButton: some View {
        Button("folders.contextmenu.open_new_window".localized) {
            onOpenInNewWindow()
        }
    }
    
    private var revealContextMenuButton: some View {
        Button("folders.contextmenu.reveal".localized) {
            onSecondaryAction()
        }
    }
    
    private var renameContextMenuButton: some View {
        Button("folders.contextmenu.rename".localized) {
            onStartRename()
        }
    }
    
    private var deleteContextMenuButton: some View {
        Button("folders.contextmenu.delete".localized, role: .destructive) {
            onDelete()
        }
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
            leadingContent
            
            folderDetails
            
            Spacer()
            
            if isHovered || showSelectionMode {
                trailingActionButtons
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(listItemBackground)
        .overlay(listItemBorder)
        .scaleEffect(isHovered ? 1.005 : 1.0, anchor: .leading)
        .onTapGesture {
            onPrimaryAction()
        }
        .contextMenu {
            contextMenuContent
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            onFileDrop(providers)
        }
        .animation(DesignSystem.Animation.spring, value: isHovered)
        .animation(DesignSystem.Animation.standard, value: isSelected)
    }
    
    // MARK: - Extracted Subviews
    
    private var leadingContent: some View {
        Group {
            if showSelectionMode {
                selectionButton
            }
            
            folderIcon
        }
    }
    
    private var selectionButton: some View {
        Button(action: onToggleSelection) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                .font(DesignSystem.Typography.title3)
        }
        .buttonStyle(.plain)
    }
    
    private var folderIcon: some View {
        Image(systemName: folder.systemImage)
            .font(.system(size: 24))
            .foregroundColor(.blue)
            .frame(width: 32)
            .scaleEffect(isHovered || isDraggingOver ? 1.05 : 1.0)
            .animation(DesignSystem.Animation.spring, value: isHovered)
            .animation(DesignSystem.Animation.spring, value: isDraggingOver)
    }
    
    private var folderDetails: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            folderNameRow
            
            folderInfoRow
            
            if !folder.tags.isEmpty {
                tagsRow
            }
        }
    }
    
    private var folderNameRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if isEditing {
                editingNameField
            } else {
                folderNameText
            }
            
            if folder.isFavorite {
                favoriteIcon
            }
            
            Spacer()
        }
    }
    
    private var editingNameField: some View {
        TextField("Folder name", text: $editingName, onCommit: {
            onRename(editingName)
        })
        .textFieldStyle(.plain)
        .font(DesignSystem.Typography.body)
        .fontWeight(.medium)
    }
    
    private var folderNameText: some View {
        Text(folder.name)
            .font(DesignSystem.Typography.body)
            .fontWeight(.medium)
            .foregroundColor(DesignSystem.Colors.primaryText)
    }
    
    private var favoriteIcon: some View {
        Image(systemName: "star.fill")
            .foregroundColor(.yellow)
            .font(DesignSystem.Typography.caption)
    }
    
    private var folderInfoRow: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            itemCountText
            
            separatorDot
            
            dateAddedText
            
            Spacer()
        }
    }
    
    private var itemCountText: some View {
        Text(folder.itemCountString)
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.secondaryText)
    }
    
    private var separatorDot: some View {
        Text("•")
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.secondaryText)
    }
    
    private var dateAddedText: some View {
        Text(folder.dateAdded.formatted(.relative(presentation: .named)))
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.secondaryText)
    }
    
    private var tagsRow: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(Array(folder.tags), id: \.self) { tag in
                Text(tag)
                    .tagStyle(color: .blue)
            }
        }
    }
    
    private var trailingActionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            favoriteActionButton
            
            openNewWindowButton
            
            deleteActionButton
        }
        .transition(actionButtonsTransition)
    }
    
    private var favoriteActionButton: some View {
        ActionButton(
            icon: folder.isFavorite ? "star.fill" : "star",
            color: folder.isFavorite ? .yellow : DesignSystem.Colors.secondaryText,
            action: onToggleFavorite,
            tooltip: folder.isFavorite ? "folders.contextmenu.unfavorite".localized : "folders.contextmenu.favorite".localized
        )
    }
    
    private var openNewWindowButton: some View {
        ActionButton(
            icon: "arrow.up.forward.square",
            color: DesignSystem.Colors.secondaryText,
            action: onOpenInNewWindow,
            tooltip: "folders.contextmenu.open_new_window".localized
        )
    }
    
    private var deleteActionButton: some View {
        ActionButton(
            icon: "trash",
            color: DesignSystem.Colors.error,
            action: onDelete,
            tooltip: "folders.contextmenu.delete".localized
        )
    }
    
    private var actionButtonsTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
    
    private var listItemBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
            .fill(backgroundMaterial)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
    }
    
    private var listItemBorder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }
    
    private var contextMenuContent: some View {
        Group {
            favoriteContextMenuButton
            
            Divider()
            
            openContextMenuButton
            openNewWindowContextMenuButton
            revealContextMenuButton
            renameContextMenuButton
            
            Divider()
            
            deleteContextMenuButton
        }
    }
    
    private var favoriteContextMenuButton: some View {
        Button(folder.isFavorite ? "folders.contextmenu.unfavorite".localized : "folders.contextmenu.favorite".localized) {
            onToggleFavorite()
        }
    }
    
    private var openContextMenuButton: some View {
        Button("folders.contextmenu.open".localized) {
            onPrimaryAction()
        }
    }
    
    private var openNewWindowContextMenuButton: some View {
        Button("folders.contextmenu.open_new_window".localized) {
            onOpenInNewWindow()
        }
    }
    
    private var revealContextMenuButton: some View {
        Button("folders.contextmenu.reveal".localized) {
            onSecondaryAction()
        }
    }
    
    private var renameContextMenuButton: some View {
        Button("folders.contextmenu.rename".localized) {
            onStartRename()
        }
    }
    
    private var deleteContextMenuButton: some View {
        Button("folders.contextmenu.delete".localized, role: .destructive) {
            onDelete()
        }
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
struct SortMenuButton<SortOption: Hashable & CaseIterable & Identifiable & DisplayableEnum>: View 
where SortOption.AllCases: RandomAccessCollection {
    let sortOption: SortOption
    let isAscending: Bool
    let onSelectOption: (SortOption) -> Void
    let onToggleOrder: () -> Void

    @State private var isHovered = false

    var body: some View {
        Menu {
            Section("sort.by".localized) {
                ForEach(Array(SortOption.allCases), id: \.self) { option in
                    Button(action: { onSelectOption(option) }) {
                        HStack {
                            Text(option.displayName)
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
