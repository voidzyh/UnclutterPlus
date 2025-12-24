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
    @State private var showHiddenFiles = false
    
    // 动画状态
    @State private var dragOver = false
    @State private var isImporting = false
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            modernHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider()
                .background(Color.accentColor.opacity(0.1))
            
            // 内容区域
            contentArea
                .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
                    handleDrop(providers: providers)
                }
                .overlay(dragOverlay)
        }
        .onAppear {
            Task {
                await viewModel.refresh()
            }
        }
    }
    
    // MARK: - 现代化头部
    
    private var modernHeader: some View {
        VStack(spacing: 12) {
            // 主要工具栏
            HStack(spacing: 12) {
                // 搜索栏
                modernSearchBar
                
                // 视图模式切换
                viewModeSelector
                
                // 排序选项
                sortButton
                
                // 添加文件夹按钮
                addFolderButton
            }
            
            // 统计信息
            if !viewModel.statistics.isEmpty {
                statisticsView(stats: viewModel.statistics)
            }
        }
    }
    
    // MARK: - 现代化搜索栏
    
    private var modernSearchBar: some View {
        HStack(spacing: 8) {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundColor(.secondary)
            
            // 搜索输入
            TextField("Search folders...", text: $searchText)
                .font(.body)
                .textFieldStyle(.plain)
                .onSubmit {
                    viewModel.searchText = searchText
                }
                .onChange(of: searchText) { oldValue, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.searchText = newValue
                    }
                }
            
            // 清除按钮
            if !searchText.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchText = ""
                        viewModel.searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 视图模式选择器
    
    private var viewModeSelector: some View {
        Picker("View Mode", selection: $viewMode) {
            ForEach(FileViewMode.allCases, id: \.self) { mode in
                Image(systemName: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewMode) { oldValue, newValue in
            viewModel.viewMode = newValue
        }
    }
    
    // MARK: - 排序按钮
    
    private var sortButton: some View {
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
                .font(.title3)
        }
        .menuStyle(.borderedButton)
    }
    
    // MARK: - 添加文件夹按钮
    
    private var addFolderButton: some View {
        Button(action: {
            selectFolder()
        }) {
            Image(systemName: "plus.folder")
                .font(.title3)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
    
    // MARK: - 统计视图
    
    private func statisticsView(stats: [FileStatistic]) -> some View {
        HStack(spacing: 16) {
            ForEach(stats) { stat in
                FileStatisticCard(stat: stat)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 内容区域
    
    private var contentArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    // 文件夹列表
                    foldersList
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    // 空状态
                    if viewModel.filteredFolders.isEmpty {
                        emptyStateView
                    }
                }
                .background(GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scrollView")).minY)
                })
            }
            .coordinateSpace(name: "scrollView")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = -value
            }
        }
    }
    
    // MARK: - 文件夹列表
    
    private var foldersList: some View {
        Group {
            switch viewMode {
            case .grid:
                gridView
            case .list:
                listView
            }
        }
    }
    
    // MARK: - 网格视图
    
    private var gridView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.filteredFolders) { folder in
                folderGridItem(folder)
            }
        }
    }
    
    // MARK: - 列表视图
    
    private var listView: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.filteredFolders) { folder in
                folderListItem(folder)
            }
        }
    }
    
    // MARK: - 文件夹网格项
    
    private func folderGridItem(_ folder: FavoriteFolder) -> some View {
        VStack(spacing: 8) {
            // 文件夹图标
            Image(systemName: folderIcon(for: folder))
                .font(.system(size: 32))
                .foregroundColor(folderColor(for: folder))
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            
            // 文件夹名称
            Text(folder.name)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
            
            // 文件数量
            Text("\(folder.fileCount) items")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture {
            handleFolderTap(folder)
        }
        .contextMenu {
            Button("Open") {
                Task {
                    await viewModel.openFolder(folder)
                }
            }
            
            Button("Open in New Window") {
                Task {
                    await viewModel.openFolderInNewWindow(folder)
                }
            }
            
            Button("Show in Finder") {
                Task {
                    await viewModel.showInFinder(folder)
                }
            }
            
            Divider()
            
            Button(folder.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                Task {
                    await viewModel.toggleFavorite(folder)
                }
            }
            
            Divider()
            
            Button("Delete") {
                Task {
                    await viewModel.deleteFolder(folder)
                }
            }
        }
    }
    
    // MARK: - 文件夹列表项
    
    private func folderListItem(_ folder: FavoriteFolder) -> some View {
        HStack(spacing: 12) {
            // 文件夹图标
            Image(systemName: folderIcon(for: folder))
                .font(.title2)
                .foregroundColor(folderColor(for: folder))
                .frame(width: 24, height: 24)
            
            // 文件夹信息
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(folder.url.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                if folder.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                
                Text("\(folder.fileCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    Task {
                        await viewModel.openFolder(folder)
                    }
                }) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .onTapGesture {
            handleFolderTap(folder)
        }
        .contextMenu {
            Button("Open") {
                Task {
                    await viewModel.openFolder(folder)
                }
            }
            
            Button("Open in New Window") {
                Task {
                    await viewModel.openFolderInNewWindow(folder)
                }
            }
            
            Button("Show in Finder") {
                Task {
                    await viewModel.showInFinder(folder)
                }
            }
            
            Divider()
            
            Button(folder.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                Task {
                    await viewModel.toggleFavorite(folder)
                }
            }
            
            Divider()
            
            Button("Delete") {
                Task {
                    await viewModel.deleteFolder(folder)
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func folderIcon(for folder: FavoriteFolder) -> String {
        if folder.isFavorite {
            return "star.fill"
        }
        return folder.customIcon ?? "folder"
    }
    
    private func folderColor(for folder: FavoriteFolder) -> Color {
        if folder.isFavorite {
            return .yellow
        }
        return .blue
    }
    
    private func handleFolderTap(_ folder: FavoriteFolder) {
        Task {
            await viewModel.openFolder(folder)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // 处理拖拽的文件
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, error in
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    logger.info("Dropped file: \(url)", category: "ModernFilesView")
                }
            }
        }
        return true
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                Task {
                    await viewModel.addFolder(url)
                }
            }
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text("No Folders")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Add your favorite folders to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add Folder") {
                selectFolder()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - 拖拽覆盖层
    
    private var dragOverlay: some View {
        Group {
            if dragOver {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundColor(.accentColor)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                    .padding()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: dragOver)
            }
        }
    }
}

// MARK: - 统计卡片组件

struct FileStatisticCard: View {
    let stat: FileStatistic
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: stat.icon)
                    .font(.caption)
                    .foregroundColor(stat.color)
                
                Text(stat.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(stat.value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - 预览

struct ModernFilesView_Previews: PreviewProvider {
    static var previews: some View {
        ModernFilesView()
            .frame(width: 800, height: 600)
    }
}