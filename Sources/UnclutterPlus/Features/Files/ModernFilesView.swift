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
            
            // 内容区域
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
        // Simple implementation for drop
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                    if let urlData = urlData as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                        Task { await viewModel.addFolder(url) }
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
