import SwiftUI
import Combine

/// 现代化剪贴板视图 - 流畅动画和智能交互
struct ModernClipboardView: View {
    @StateObject private var viewModel = ModernClipboardViewModel()
    @Namespace private var clipboardNamespace
    
    // 状态管理
    @State private var selectedItem: UUID?
    @State private var searchText: String = ""
    @State private var isSearching = false
    @State private var showFilters = false
    @State private var scrollOffset: CGFloat = 0
    
    // 动画状态
    @State private var itemsOpacity: Double = 1.0
    @State private var headerBlur: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏 - 带有动态模糊效果
            modernHeader
                .background(
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        .opacity(scrollOffset > 10 ? 1 : 0)
                )
                .overlay(alignment: .bottom) {
                    if scrollOffset > 10 {
                        Divider()
                            .background(Color.accentColor.opacity(0.1))
                    }
                }
            
            // 内容区域
            contentArea
                .coordinateSpace(name: "scrollView")
        }
        .onAppear {
            Task {
                await viewModel.loadInitialData()
            }
        }
    }
    
    // MARK: - 现代化头部
    
    private var modernHeader: some View {
        VStack(spacing: 12) {
            // 搜索栏和工具
            HStack(spacing: 12) {
                // 现代化搜索栏
                modernSearchBar
                
                // 过滤按钮
                filterButton
                
                // 清除按钮
                clearButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // 过滤器面板
            if showFilters {
                filterPanel
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - 现代化搜索栏
    
    private var modernSearchBar: some View {
        HStack(spacing: 8) {
            // 搜索图标 - 带动画效果
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundColor(.secondary)
            
            // 搜索输入
            TextField("Search clipboard...", text: $searchText)
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
        .overlay(alignment: .trailing) {
            if viewModel.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 12)
            }
        }
    }
    
    // MARK: - 过滤按钮
    
    private var filterButton: some View {
        Button(action: {
            withAnimation(.spring()) {
                showFilters.toggle()
            }
        }) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(showFilters ? .accentColor : .primary)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .background(
            Group {
                if showFilters {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .matchedGeometryEffect(id: "filterBackground", in: clipboardNamespace)
                }
            }
        )
    }
    
    // MARK: - 清除按钮
    
    private var clearButton: some View {
        Button(role: .destructive) {
            Task {
                await viewModel.clearAll()
            }
        } label: {
            Image(systemName: "trash")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(viewModel.clipboardItems.isEmpty)
    }
    
    // MARK: - 过滤器面板
    
    private var filterPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 内容类型过滤
                ForEach(ClipboardContentType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.title,
                        icon: type.icon,
                        isSelected: viewModel.selectedContentType == type,
                        color: type.color
                    ) {
                        viewModel.selectedContentType = type
                    }
                }
                
                // 日期范围过滤
                ForEach(DateRange.allCases, id: \.self) { range in
                    FilterChip(
                        title: range.title,
                        icon: range.icon,
                        isSelected: viewModel.selectedDateRange == range,
                        color: .orange
                    ) {
                        viewModel.selectedDateRange = range
                    }
                }
                
                // 排序选项
                ForEach(SortOption.allCases, id: \.self) { option in
                    FilterChip(
                        title: option.title,
                        icon: option.icon,
                        isSelected: viewModel.sortOption == option,
                        color: .green
                    ) {
                        viewModel.sortOption = option
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
    
    // MARK: - 内容区域
    
    private var contentArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    // 统计信息
                    if !viewModel.clipboardItems.isEmpty {
                        statisticsView
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }
                    
                    // 剪贴板项目列表
                    clipboardItemsList
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .background(GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scrollView")).minY)
                })
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = -value
            }
            .onChange(of: viewModel.clipboardItems.count) { oldValue, newValue in
                if newValue > oldValue {
                    // 新项目添加时滚动到顶部
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        }
    }
    
    // MARK: - 统计视图
    
    private var statisticsView: some View {
        HStack(spacing: 16) {
            ForEach(viewModel.statistics) { stat in
                StatisticCard(title: stat.title, value: stat.value, icon: stat.icon, color: stat.color)
            }
        }
    }
    
    // MARK: - 剪贴板项目列表
    
    private var clipboardItemsList: some View {
        LazyVStack(spacing: 8) {
            // 顶部锚点
            Color.clear
                .frame(height: 1)
                .id("top")
            
            // 项目列表
            ForEach(viewModel.filteredItems) { item in
                ClipboardItemView(
                    item: item,
                    isSelected: selectedItem == item.id,
                    namespace: clipboardNamespace
                ) {
                    selectItem(item)
                } onCopy: {
                    copyItem(item)
                } onDelete: {
                    deleteItem(item)
                }
                .id(item.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3), value: viewModel.filteredItems.count)
            }
            
            // 空状态
            if viewModel.filteredItems.isEmpty {
                emptyResultsView
            }
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clipboard")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text("No clipboard items")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Copy something to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .padding(.top, 32)
    }
    
    // MARK: - 事件处理
    
    private func selectItem(_ item: ClipboardItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedItem = item.id
        }
    }
    
    private func copyItem(_ item: ClipboardItem) {
        Task {
            await viewModel.copyToClipboard(item)
        }
    }
    
    private func deleteItem(_ item: ClipboardItem) {
        Task {
            await viewModel.deleteItem(item)
        }
    }
}

// MARK: - 偏好键

// MARK: - 过滤芯片组件

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.secondary.opacity(0.2))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}



// MARK: - 剪贴板项目视图

struct ClipboardItemView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 内容图标
            contentIcon
            
            // 内容预览
            contentPreview
            
            Spacer()
            
            // 操作按钮
            actionButtons
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Copy") {
                onCopy()
            }
            
            Button("Delete") {
                onDelete()
            }
        }
    }
    
    private var contentIcon: some View {
        Group {
            switch item.content {
            case .text:
                Image(systemName: "text.alignleft")
                    .font(.title2)
                    .foregroundColor(.blue)
            case .image:
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.orange)
            case .file:
                Image(systemName: "doc")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
        .frame(width: 24, height: 24)
    }
    
    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch item.content {
            case .text(let text):
                Text(text.prefix(100))
                    .font(.body)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            case .image:
                Text("Image")
                    .font(.body)
                    .foregroundColor(.primary)
            case .file(let url):
                Text(url.lastPathComponent)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            HStack {
                Text(formattedDate(item.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 预览

struct ModernClipboardView_Previews: PreviewProvider {
    static var previews: some View {
        ModernClipboardView()
            .frame(width: 600, height: 800)
    }
}