import SwiftUI
import UniformTypeIdentifiers
import Combine

/// 现代化文件管理视图 - 改进的交互体验和流畅动画
struct ModernFilesView: View {
    @StateObject private var viewModel = ModernFilesViewModel()
    @Namespace private var filesNamespace
    
    // 状态管理
    @State private var selectedFolders: Set<UUID> = []
    @State private var searchText: String = ""
    @State private var viewMode: FileViewMode = .grid
    @State private var sortOption: FileSortOption = .dateNewest
    
    // 动画状态
    @State private var dragOver = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 统计条 (如果需要)
            if !viewModel.statistics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ModernDesignSystem.Spacing.md) {
                        ForEach(viewModel.statistics) { stat in
                            ModernStatChip(icon: stat.icon, label: stat.title, value: stat.value, color: stat.color)
                        }
                    }
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                .background(ModernDesignSystem.shared.color(.bgCanvas))
            }
            
            // 暂存区（drop zone）—— 拖入文件暂存、拖出到任意应用
            stagedFilesSection
                .overlay(
                    Rectangle()
                        .fill(ModernDesignSystem.shared.color(.strokeAdaptive))
                        .frame(height: 1),
                    alignment: .bottom
                )
            
            // 内容区域（收藏文件夹）
            contentArea
                .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
                    handleDrop(providers: providers)
                }
                .overlay(dragOverlay)
        }
        .background(ModernDesignSystem.shared.color(.bgCanvas))
        .onAppear {
            Task { await viewModel.refresh() }
        }
        // 使用原生 Searchable
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search folders...")
        .onChange(of: searchText) { _, newValue in
             viewModel.searchText = newValue
        }
        // 使用原生 Toolbar
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("View Mode", selection: $viewMode) {
                    ForEach(FileViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                Menu {
                    ForEach(FileSortOption.allCases, id: \.self) { option in
                        Button(action: {
                            viewModel.sortOption = option
                            sortOption = option
                        }) {
                            HStack {
                                Image(systemName: option.systemImage)
                                Text(option.rawValue)
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14))
                }
                
                Button(action: { selectFolder() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }
    
    // MARK: - 暂存区（drop zone）
    
    private var stagedFilesSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Label("files.staged.title".localized, systemImage: "tray.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ModernDesignSystem.shared.color(.textSecondary))
                
                Text("\(viewModel.stagedFiles.count)")
                    .font(.caption2)
                    .foregroundColor(ModernDesignSystem.shared.color(.textTertiary))
                
                Spacer()
                
                Button(action: { viewModel.clearStagedFiles() }) {
                    Text("files.staged.clear".localized)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .disabled(viewModel.stagedFiles.isEmpty)
                .help("files.staged.clear_help".localized)
            }
            
            if viewModel.stagedFiles.isEmpty {
                Text("files.staged.empty".localized)
                    .font(.caption)
                    .foregroundColor(ModernDesignSystem.shared.color(.textTertiary))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, ModernDesignSystem.Spacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        ForEach(viewModel.stagedFiles) { item in
                            StagedFileChip(
                                item: item,
                                onTap: { viewModel.openStagedFile(item) },
                                onQuickLook: { QuickLookController.shared.togglePreview(for: item.url) },
                                onReveal: { viewModel.revealStagedFile(item) },
                                onRemove: { viewModel.removeStagedFile(item) },
                                onDragOut: { viewModel.recordStagedFileAccess(item) }
                            )
                        }
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                }
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
    }
    
    // MARK: - 内容区域
    
    private var contentArea: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                if viewModel.filteredFolders.isEmpty {
                    emptyStateView
                } else {
                    foldersList
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
    }
    
    private var foldersList: some View {
        Group {
            switch viewMode {
            case .grid:
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.filteredFolders) { folder in
                        FolderGridItem(folder: folder, onTap: { handleFolderTap(folder) })
                            .contextMenu { folderContextMenu(folder) }
                    }
                }
            case .list:
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.filteredFolders) { folder in
                        FolderListItem(folder: folder, onTap: { handleFolderTap(folder) })
                            .contextMenu { folderContextMenu(folder) }
                    }
                }
            }
        }
    }
    
    private func folderContextMenu(_ folder: FavoriteFolder) -> some View {
        Group {
            Button("Open") { Task { await viewModel.openFolder(folder) } }
            Button("Show in Finder") { Task { await viewModel.showInFinder(folder) } }
            Divider()
            Button(folder.isFavorite ? "Unfavorite" : "Favorite") {
                Task { await viewModel.toggleFavorite(folder) }
            }
            Divider()
            Button("Remove") { Task { await viewModel.deleteFolder(folder) } }
        }
    }
    
    // MARK: - 拖拽覆盖层
    
    private var dragOverlay: some View {
        Group {
            if dragOver {
                ZStack {
                    ModernDesignSystem.shared.color(.bgSurface).opacity(0.9)
                    
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                            .symbolEffect(.pulse)
                        
                        Text("Drop to add folder")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(ModernDesignSystem.shared.color(.textTertiary))
            
            Text("No folders yet")
                .font(.title3)
                .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
            
            Text("Add folders to quickly access your files")
                .font(.body)
                .foregroundColor(ModernDesignSystem.shared.color(.textSecondary))
            
            Button("Add Folder") { selectFolder() }
                .buttonStyle(.bordered)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Actions
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.addFolder(url) }
        }
    }
    
    private func handleFolderTap(_ folder: FavoriteFolder) {
        Task { await viewModel.openFolder(folder) }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // 拖入路由：目录 → 收藏文件夹；文件 → 暂存区
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                    if let urlData = urlData as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                        Task { @MainActor in
                            if ModernFilesViewModel.isDirectory(url) {
                                await viewModel.addFolder(url)
                            } else {
                                viewModel.stageFile(url)
                            }
                        }
                    }
                }
            }
        }
        return true
    }
}

// MARK: - 子组件

struct FolderGridItem: View {
    let folder: FavoriteFolder
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: folder.isFavorite ? "star.fill" : "folder.fill")
                        .font(.system(size: 20))
                        .foregroundColor(folder.isFavorite ? .yellow : .blue)
                }
                
                Spacer()
                
                // Badge
                Text("\(folder.fileCount)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.headline)
                    .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
                    .lineLimit(1)
                
                Text(folder.url.path)
                    .font(.caption)
                    .foregroundColor(ModernDesignSystem.shared.color(.textSecondary))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(16)
        .cardStyle(hover: true)
        .onTapGesture(perform: onTap)
        .hoverScaleEffect()
    }
}

struct FolderListItem: View {
    let folder: FavoriteFolder
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folder.isFavorite ? "star.fill" : "folder.fill")
                .font(.title3)
                .foregroundColor(folder.isFavorite ? .yellow : .blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
                Text(folder.url.path)
                    .font(.caption)
                    .foregroundColor(ModernDesignSystem.shared.color(.textTertiary))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("\(folder.fileCount) items")
                .font(.caption)
                .foregroundColor(ModernDesignSystem.shared.color(.textSecondary))
        }
        .padding(12)
        .background(ModernDesignSystem.shared.color(.bgSurface))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .onTapGesture(perform: onTap)
        .hoverScaleEffect(scale: 1.01)
    }
}

// MARK: - 暂存文件组件

/// 暂存区文件卡片：拖出到任意应用、点击打开、悬停显示操作、右键菜单（Quick Look/揭示/移除）
struct StagedFileChip: View {
    let item: TempFileItem
    let onTap: () -> Void
    let onQuickLook: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void
    let onDragOut: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: item.exists ? "doc" : "doc.badge.plus")
                .font(.system(size: 22))
                .foregroundColor(item.exists ? .blue : ModernDesignSystem.shared.color(.textTertiary))

            Text(item.name)
                .font(.caption2)
                .foregroundColor(item.exists ? ModernDesignSystem.shared.color(.textPrimary) : ModernDesignSystem.shared.color(.textTertiary))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 76, height: 64)
        .background(ModernDesignSystem.shared.color(.bgSurface))
        .cornerRadius(ModernDesignSystem.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Radius.sm)
                .stroke(isHovered ? ModernDesignSystem.shared.color(.borderFocus) : ModernDesignSystem.shared.color(.strokeAdaptive), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(3)
                .help("files.staged.remove".localized)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("files.staged.open".localized, action: onTap)
            Button("files.staged.quicklook".localized, action: onQuickLook)
            Button("files.staged.reveal".localized, action: onReveal)
            Divider()
            Button("files.staged.remove".localized, role: .destructive, action: onRemove)
        }
        .help(item.exists ? item.url.path : "files.staged.missing".localized)
        .onDrag {
            // 拖出：向任意应用提供文件 URL（Finder/其他应用执行复制或移动）
            onDragOut()
            return NSItemProvider(object: item.url as NSURL)
        }
    }
}
