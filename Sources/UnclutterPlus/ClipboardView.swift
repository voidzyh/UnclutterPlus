import SwiftUI

struct ClipboardView: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @StateObject private var config = ConfigurationManager.shared
    @State private var searchText = ""
    @State private var selectedItems: Set<UUID> = []
    @State private var hoveredItem: UUID?
    @State private var isMultiSelectMode = false
    @State private var selectedIndex: Int = -1
    
    // 过滤和排序状态
    @State private var selectedContentType: String = "all" // "all", "text", "image", "file"
    @State private var selectedSourceApp: String = "all"
    @State private var selectedDateRange: String = "all" // "all", "today", "week", "month"
    @State private var sortBy: String = "time" // "time", "useCount"
    
    // 过滤器展开状态
    @State private var showTypeFilter: Bool = false
    @State private var showSourceFilter: Bool = false
    @State private var showDateFilter: Bool = false
    @State private var showSortFilter: Bool = false
    // 工具栏悬停状态
    @State private var hoveredToolbar: String? = nil
    
    var filteredItems: [ClipboardItem] {
        var items = clipboardManager.items
        
        // 内容类型过滤
        if selectedContentType != "all" {
            items = items.filter { item in
                switch item.content {
                case .text:
                    return selectedContentType == "text"
                case .image:
                    return selectedContentType == "image"
                case .file:
                    return selectedContentType == "file"
                }
            }
        }
        
        // 来源应用过滤
        if selectedSourceApp != "all" {
            items = items.filter { item in
                item.sourceAppBundleID == selectedSourceApp
            }
        }
        
        // 日期范围过滤
        if selectedDateRange != "all" {
            let calendar = Calendar.current
            let now = Date()
            let cutoffDate: Date
            
            switch selectedDateRange {
            case "today":
                cutoffDate = calendar.startOfDay(for: now)
            case "week":
                cutoffDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case "month":
                cutoffDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            default:
                cutoffDate = now
            }
            
            items = items.filter { item in
                item.timestamp >= cutoffDate
            }
        }
        
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
        
        // 排序
        return items.sorted { first, second in
            if first.isPinned && !second.isPinned {
                return true
            } else if !first.isPinned && second.isPinned {
                return false
            } else {
                switch sortBy {
                case "useCount":
                    return first.useCount > second.useCount
                default: // "time"
                    return first.timestamp > second.timestamp
                }
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
                    
                    TextField("clipboard.search.placeholder".localized, text: $searchText)
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
                                                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                
                // 过滤和排序控件（仅图标按钮，点击后弹出选项）
                HStack(spacing: 12) {
                    // 类型
                    Button(action: {
                        if showTypeFilter { showTypeFilter = false } else {
                            showTypeFilter = true
                            showDateFilter = false
                            showSourceFilter = false
                            showSortFilter = false
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundColor((selectedContentType != "all") ? .blue : (hoveredToolbar == "type" ? .primary : .primary))
                                .background(
                                    (selectedContentType != "all"
                                        ? Color.blue.opacity(0.15)
                                        : (hoveredToolbar == "type" ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.08))),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            (selectedContentType != "all") ? Color.blue.opacity(0.4) : (hoveredToolbar == "type" ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.2)),
                                            lineWidth: 1
                                        )
                                )
                                .scaleEffect(hoveredToolbar == "type" ? 1.03 : 1.0)
                                .animation(.easeInOut(duration: 0.12), value: hoveredToolbar == "type")
                            if selectedContentType != "all" {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { isHover in
                        hoveredToolbar = isHover ? "type" : (hoveredToolbar == "type" ? nil : hoveredToolbar)
                    }

                    // 日期
                    Button(action: {
                        if showDateFilter { showDateFilter = false } else {
                            showTypeFilter = false
                            showDateFilter = true
                            showSourceFilter = false
                            showSortFilter = false
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundColor((selectedDateRange != "all") ? .red : (hoveredToolbar == "date" ? .primary : .primary))
                                .background(
                                    (selectedDateRange != "all"
                                        ? Color.red.opacity(0.15)
                                        : (hoveredToolbar == "date" ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.08))),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            (selectedDateRange != "all") ? Color.red.opacity(0.4) : (hoveredToolbar == "date" ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.2)),
                                            lineWidth: 1
                                        )
                                )
                                .scaleEffect(hoveredToolbar == "date" ? 1.03 : 1.0)
                                .animation(.easeInOut(duration: 0.12), value: hoveredToolbar == "date")
                            if selectedDateRange != "all" {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { isHover in
                        hoveredToolbar = isHover ? "date" : (hoveredToolbar == "date" ? nil : hoveredToolbar)
                    }

                    // 来源
                    Button(action: {
                        if showSourceFilter { showSourceFilter = false } else {
                            showTypeFilter = false
                            showDateFilter = false
                            showSourceFilter = true
                            showSortFilter = false
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "app.badge")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundColor((selectedSourceApp != "all") ? .purple : (hoveredToolbar == "source" ? .primary : .primary))
                                .background(
                                    (selectedSourceApp != "all"
                                        ? Color.purple.opacity(0.15)
                                        : (hoveredToolbar == "source" ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.08))),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            (selectedSourceApp != "all") ? Color.purple.opacity(0.4) : (hoveredToolbar == "source" ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.2)),
                                            lineWidth: 1
                                        )
                                )
                                .scaleEffect(hoveredToolbar == "source" ? 1.03 : 1.0)
                                .animation(.easeInOut(duration: 0.12), value: hoveredToolbar == "source")
                            if selectedSourceApp != "all" {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { isHover in
                        hoveredToolbar = isHover ? "source" : (hoveredToolbar == "source" ? nil : hoveredToolbar)
                    }

                    Spacer()

                    // 排序
                    Button(action: {
                        if showSortFilter { showSortFilter = false } else {
                            showTypeFilter = false
                            showDateFilter = false
                            showSourceFilter = false
                            showSortFilter = true
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundColor((sortBy != "time") ? .indigo : (hoveredToolbar == "sort" ? .primary : .primary))
                                .background(
                                    (sortBy != "time"
                                        ? Color.indigo.opacity(0.15)
                                        : (hoveredToolbar == "sort" ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.08))),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            (sortBy != "time") ? Color.indigo.opacity(0.4) : (hoveredToolbar == "sort" ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.2)),
                                            lineWidth: 1
                                        )
                                )
                                .scaleEffect(hoveredToolbar == "sort" ? 1.03 : 1.0)
                                .animation(.easeInOut(duration: 0.12), value: hoveredToolbar == "sort")
                            if sortBy != "time" {
                                Circle()
                                    .fill(Color.indigo)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { isHover in
                        hoveredToolbar = isHover ? "sort" : (hoveredToolbar == "sort" ? nil : hoveredToolbar)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
                )

                // 下拉面板（在工具栏下方划出）
                if showTypeFilter || showDateFilter || showSourceFilter || showSortFilter {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                        if showTypeFilter {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(title: "clipboard.filter.all".localized, icon: "square.grid.2x2", isSelected: selectedContentType == "all", color: .blue) { selectedContentType = "all"; showTypeFilter = false }
                                    FilterChip(title: "clipboard.filter.text".localized, icon: "doc.plaintext", isSelected: selectedContentType == "text", color: .blue) { selectedContentType = "text"; showTypeFilter = false }
                                    FilterChip(title: "clipboard.filter.image".localized, icon: "photo", isSelected: selectedContentType == "image", color: .green) { selectedContentType = "image"; showTypeFilter = false }
                                    FilterChip(title: "clipboard.filter.file".localized, icon: "doc", isSelected: selectedContentType == "file", color: .orange) { selectedContentType = "file"; showTypeFilter = false }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        if showDateFilter {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(title: "clipboard.filter.all".localized, icon: "calendar", isSelected: selectedDateRange == "all", color: .red) { selectedDateRange = "all"; showDateFilter = false }
                                    FilterChip(title: "clipboard.filter.today".localized, icon: "sun.max", isSelected: selectedDateRange == "today", color: .red) { selectedDateRange = "today"; showDateFilter = false }
                                    FilterChip(title: "clipboard.filter.week".localized, icon: "clock", isSelected: selectedDateRange == "week", color: .red) { selectedDateRange = "week"; showDateFilter = false }
                                    FilterChip(title: "clipboard.filter.month".localized, icon: "calendar", isSelected: selectedDateRange == "month", color: .red) { selectedDateRange = "month"; showDateFilter = false }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        if showSourceFilter {
                            HStack(spacing: 8) {
                                FilterChip(title: "clipboard.filter.all".localized, isSelected: selectedSourceApp == "all", color: .purple) { selectedSourceApp = "all" }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(Set(clipboardManager.items.compactMap { $0.sourceAppBundleID })).sorted(), id: \.self) { bundleID in
                                            if let item = clipboardManager.items.first(where: { $0.sourceAppBundleID == bundleID }),
                                               let iconData = item.sourceAppIcon,
                                               let image = NSImage(data: iconData) {
                                                Button(action: { selectedSourceApp = bundleID }) {
                                                    Image(nsImage: image)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 22, height: 22)
                                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 5)
                                                                .strokeBorder(
                                                                    selectedSourceApp == bundleID ? Color.purple.opacity(0.6) : Color.secondary.opacity(0.3),
                                                                    lineWidth: selectedSourceApp == bundleID ? 2 : 1
                                                                )
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                                .help(item.sourceAppName ?? bundleID)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                                Button("common.cancel".localized) { showSourceFilter = false }
                                    .buttonStyle(.borderless)
                            }
                        }

                        if showSortFilter {
                            HStack(spacing: 8) {
                                SortButton(title: "clipboard.sort.time".localized, icon: "clock", isSelected: sortBy == "time") { sortBy = "time" }
                                SortButton(title: "clipboard.sort.use_count".localized, icon: "number.circle", isSelected: sortBy == "useCount") { sortBy = "useCount" }
                                Spacer()
                                Button("common.cancel".localized) { showSortFilter = false }
                                    .buttonStyle(.borderless)
                            }
                        }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                        )
                        .frame(maxWidth: 420, alignment: .leading)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.18), value: showTypeFilter || showDateFilter || showSourceFilter || showSortFilter)
                }
                
                Spacer()
                
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
                .help(isMultiSelectMode ? "clipboard.multi_select.exit".localized : "clipboard.multi_select.enter".localized)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            if filteredItems.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "clipboard.empty.title".localized : "clipboard.empty.search.title".localized)
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "ui.copy_something_to_see".localized : "ui.try_different_search".localized)
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
                                indexNumber: nil
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
                    Button("clipboard.multi_select.delete_selected".localized + " (\(selectedItems.count))") {
                        let itemsToRemove = filteredItems.filter { selectedItems.contains($0.id) }
                        clipboardManager.removeItems(itemsToRemove)
                        selectedItems.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                } else {
                    Button("clipboard.multi_select.clear_all".localized) {
                        clipboardManager.clearAll()
                        selectedItems.removeAll()
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
                
                Text("\(filteredItems.count) \("clipboard.multi_select.items".localized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isMultiSelectMode {
                    Text("|") 
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("\(selectedItems.count) \("clipboard.multi_select.selected".localized)")
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
        
        // 触发自动隐藏窗口
        WindowManager.shared.hideWindowAfterAction(.clipboardCopied)
        
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
            // 选择框/使用频次标签
            if showSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            } else {
                // 使用频次标签
                Text("\(item.useCount)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 20)
                    .background(.tertiary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(.secondary.opacity(0.3), lineWidth: 0.5)
                    )
            }
            
            // 内容预览
            
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
                            Button(showFullText ? "clipboard.item.collapse".localized : "clipboard.item.expand".localized) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showFullText.toggle()
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                    }
                
                case .image(let image):
                    VStack(alignment: .leading, spacing: 8) {
                        // 图片预览
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        
                        // 图片信息
                        HStack {
                            Text("clipboard.item.image.content".localized)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // 显示图片尺寸
                            let size = image.size
                            Text("\(Int(size.width))×\(Int(size.height))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.tertiary.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
                        }
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
                    // 类型图标和置顶状态
                    HStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.caption)
                            .foregroundColor(item.typeColor)
                            .frame(width: 16)
                        
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 来源应用信息
                    if let appName = item.sourceAppName {
                        HStack(spacing: 4) {
                            if let iconData = item.sourceAppIcon,
                               let image = NSImage(data: iconData) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                            
                            Text(appName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(item.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if case .text(let text) = item.content {
                        Spacer()
                        Text("\(text.count) \("clipboard.item.characters".localized)")
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
                    .help(item.isPinned ? "clipboard.item.unpin".localized : "clipboard.item.pin".localized)
                    
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help("clipboard.item.copy".localized)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("clipboard.item.delete".localized)
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
            Button(item.isPinned ? "clipboard.item.unpin".localized : "clipboard.item.pin".localized) {
                onTogglePin()
            }
            
            Divider()
            
            Button("clipboard.item.copy".localized) {
                onCopy()
            }
            
            Button("clipboard.item.delete".localized, role: .destructive) {
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
            return .thinMaterial
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

// MARK: - Filter Components
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                }
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isSelected ? color.opacity(0.15) : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? color.opacity(0.4) : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .foregroundColor(isSelected ? color : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct SortButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected ? Color.indigo.opacity(0.15) : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.indigo.opacity(0.4) : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .foregroundColor(isSelected ? Color.indigo : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    ClipboardView()
        .frame(width: 800, height: 250)
}
#endif