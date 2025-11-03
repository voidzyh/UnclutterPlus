import SwiftUI
import AppKit

struct ScreenshotsView: View {
    @StateObject private var viewModel = ScreenshotsViewModel()
    @State private var hoveredScreenshot: UUID?
    @State private var editingScreenshotName: UUID?
    @State private var newScreenshotName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack(spacing: DesignSystem.Spacing.md) {
                // 搜索栏
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .font(DesignSystem.Typography.caption)

                    TextField("screenshots.search.placeholder".localized, text: $viewModel.searchText)
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

                // 多选模式切换
                MultiSelectButton(
                    isActive: viewModel.isMultiSelectMode,
                    action: { viewModel.toggleMultiSelectMode() }
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)
            
            if viewModel.filteredScreenshots.isEmpty {
                // 空状态
                VStack(spacing: 20) {
                    if viewModel.searchText.isEmpty {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary)
                        
                        Text("screenshots.empty.title".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("screenshots.empty.subtitle".localized)
                            .font(.callout)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("screenshots.no_matching".localized)
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("ui.try_different_search".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 截图内容区域
                ScrollView {
                    switch viewModel.viewMode {
                    case .grid:
                        gridView
                    case .list:
                        listView
                    }
                }
            }
            
            // 底部状态栏
            HStack {
                if viewModel.isMultiSelectMode && !viewModel.selectedScreenshots.isEmpty {
                    Button("screenshots.delete_selected".localized + " (\(viewModel.selectedScreenshots.count))") {
                        let selectedScreenshots = viewModel.filteredScreenshots.filter { viewModel.selectedScreenshots.contains($0.id) }
                        viewModel.deleteSelectedScreenshots(selectedScreenshots)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                } else {
                    Button("screenshots.clear_all".localized) {
                        viewModel.clearAllScreenshots()
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Text("\(viewModel.filteredScreenshots.count) " + "screenshots.count".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if viewModel.isMultiSelectMode {
                    Text("|")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("\(viewModel.selectedScreenshots.count) " + "screenshots.selected".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onKeyDown { event in
            handleKeyDown(event)
        }
    }
    
    private var gridView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.filteredScreenshots) { screenshot in
                screenshotGridItem(screenshot)
            }
        }
        .padding()
    }

    private func screenshotGridItem(_ screenshot: ScreenshotItem) -> some View {
        ScreenshotItemGridView(
            screenshot: screenshot,
            isSelected: viewModel.selectedScreenshots.contains(screenshot.id),
            isHovered: hoveredScreenshot == screenshot.id,
            showSelectionMode: viewModel.isMultiSelectMode,
            isEditing: editingScreenshotName == screenshot.id,
            editingName: $newScreenshotName
        ) {
            handleScreenshotTap(screenshot)
        } onSecondaryAction: {
            viewModel.showInFinder(screenshot)
        } onDelete: {
            viewModel.deleteScreenshot(screenshot)
        } onToggleFavorite: {
            viewModel.toggleFavorite(screenshot)
        } onToggleSelection: {
            viewModel.toggleSelection(screenshot)
        } onRename: { newName in
            viewModel.renameScreenshot(screenshot, to: newName)
            editingScreenshotName = nil
        } onStartRename: {
            editingScreenshotName = screenshot.id
            newScreenshotName = screenshot.title
        } onCopyImage: {
            viewModel.copyScreenshot(screenshot)
        } onCopyText: {
            viewModel.copyOCRText(screenshot)
        } onPerformOCR: {
            viewModel.performOCR(screenshot)
        }
        .onHover { isHovering in
            hoveredScreenshot = isHovering ? screenshot.id : nil
        }
    }

    private func handleScreenshotTap(_ screenshot: ScreenshotItem) {
        if viewModel.isMultiSelectMode {
            viewModel.toggleSelection(screenshot)
        } else {
            viewModel.openScreenshot(screenshot)
        }
    }
    
    private var listView: some View {
        LazyVStack(spacing: 2) {
            ForEach(viewModel.filteredScreenshots) { screenshot in
                screenshotListItem(screenshot)
            }
        }
        .padding()
    }

    private func screenshotListItem(_ screenshot: ScreenshotItem) -> some View {
        ScreenshotItemListView(
            screenshot: screenshot,
            isSelected: viewModel.selectedScreenshots.contains(screenshot.id),
            isHovered: hoveredScreenshot == screenshot.id,
            showSelectionMode: viewModel.isMultiSelectMode,
            isEditing: editingScreenshotName == screenshot.id,
            editingName: $newScreenshotName
        ) {
            handleScreenshotTap(screenshot)
        } onSecondaryAction: {
            viewModel.showInFinder(screenshot)
        } onDelete: {
            viewModel.deleteScreenshot(screenshot)
        } onToggleFavorite: {
            viewModel.toggleFavorite(screenshot)
        } onToggleSelection: {
            viewModel.toggleSelection(screenshot)
        } onRename: { newName in
            viewModel.renameScreenshot(screenshot, to: newName)
            editingScreenshotName = nil
        } onStartRename: {
            editingScreenshotName = screenshot.id
            newScreenshotName = screenshot.title
        } onCopyImage: {
            viewModel.copyScreenshot(screenshot)
        } onCopyText: {
            viewModel.copyOCRText(screenshot)
        } onPerformOCR: {
            viewModel.performOCR(screenshot)
        }
        .onHover { isHovering in
            hoveredScreenshot = isHovering ? screenshot.id : nil
        }
    }
    
    private func sourceDisplayName(_ source: ScreenshotSource) -> String {
        switch source {
        case .region:
            return "区域截图"
        case .window:
            return "窗口截图"
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags

        // Delete 键删除选中截图
        if keyCode == 51 { // Delete key
            if !viewModel.selectedScreenshots.isEmpty {
                let selectedScreenshots = viewModel.filteredScreenshots.filter { viewModel.selectedScreenshots.contains($0.id) }
                viewModel.deleteSelectedScreenshots(selectedScreenshots)
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

// MARK: - Screenshot Item Grid View

struct ScreenshotItemGridView: View {
    let screenshot: ScreenshotItem
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
    let onCopyImage: () -> Void
    let onCopyText: () -> Void
    let onPerformOCR: () -> Void

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
                } else if screenshot.isFavorite {
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

                // 截图缩略图
                if let thumbnail = screenshot.thumbnailImage {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            // OCR 状态指示器
                            VStack {
                                HStack {
                                    Spacer()
                                    OCRStatusBadge(status: screenshot.ocrStatus)
                                }
                                Spacer()
                            }
                            .padding(DesignSystem.Spacing.xs)
                        )
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }

                // 文件名
                VStack {
                    Spacer()
                    if isEditing {
                        TextField("Screenshot name", text: $editingName, onCommit: {
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
                        Text(screenshot.title)
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .truncationMode(.middle)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .padding(.top, DesignSystem.Spacing.xs)
                    }
                }
            }

            // 悬停操作按钮
            if isHovered && !showSelectionMode && !isEditing {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if screenshot.ocrText != nil {
                        ActionButton(
                            icon: "doc.on.doc",
                            color: DesignSystem.Colors.secondaryText,
                            action: onCopyText,
                            tooltip: "screenshots.context.copy_text".localized
                        )
                    }
                    
                    ActionButton(
                        icon: screenshot.isFavorite ? "star.fill" : "star",
                        color: screenshot.isFavorite ? .yellow : DesignSystem.Colors.secondaryText,
                        action: onToggleFavorite,
                        tooltip: screenshot.isFavorite ? "screenshots.context.unfavorite".localized : "screenshots.context.favorite".localized
                    )

                    ActionButton(
                        icon: "trash",
                        color: DesignSystem.Colors.error,
                        action: onDelete,
                        tooltip: "screenshots.context.delete".localized
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
            MenuContextView(
                screenshot: screenshot,
                onToggleFavorite: onToggleFavorite,
                onPrimaryAction: onPrimaryAction,
                onSecondaryAction: onSecondaryAction,
                onRename: onStartRename,
                onCopyImage: onCopyImage,
                onCopyText: onCopyText,
                onPerformOCR: onPerformOCR,
                onDelete: onDelete
            )
        }
        .animation(DesignSystem.Animation.spring, value: isHovered)
        .animation(DesignSystem.Animation.standard, value: isSelected)
    }

    private var backgroundMaterial: Material {
        if isSelected {
            return .thick
        } else if screenshot.isFavorite {
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
        } else if screenshot.isFavorite {
            return Color.yellow.opacity(0.3)
        } else {
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        if isSelected {
            return 2
        } else if isHovered || screenshot.isFavorite {
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

// MARK: - OCR Status Badge

struct OCRStatusBadge: View {
    let status: OCRStatus
    
    var body: some View {
        Group {
            switch status {
            case .pending:
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            case .running:
                ProgressView()
                    .scaleEffect(0.5)
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.6))
        .cornerRadius(4)
    }
}

// MARK: - Screenshot Item List View

struct ScreenshotItemListView: View {
    let screenshot: ScreenshotItem
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
    let onCopyImage: () -> Void
    let onCopyText: () -> Void
    let onPerformOCR: () -> Void
    
    static func sourceDisplayName(_ source: ScreenshotSource) -> String {
        switch source {
        case .region:
            return "区域截图"
        case .window:
            return "窗口截图"
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // 选择框或缩略图
            if showSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryText)
                        .font(DesignSystem.Typography.title3)
                }
                .buttonStyle(.plain)
            }

            // 截图缩略图
            if let thumbnail = screenshot.thumbnailImage {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .cornerRadius(DesignSystem.CornerRadius.small)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 60)
            }

            // 截图信息
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if isEditing {
                        TextField("Screenshot name", text: $editingName, onCommit: {
                            onRename(editingName)
                        })
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                    } else {
                        Text(screenshot.title)
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    if screenshot.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(DesignSystem.Typography.caption)
                    }
                    
                    OCRStatusBadge(status: screenshot.ocrStatus)

                    Spacer()
                }

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(ScreenshotItemListView.sourceDisplayName(screenshot.source))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.blue)

                    Text("•")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Text(screenshot.createdAt.formatted(.relative(presentation: .named)))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    
                    if let appName = screenshot.appName {
                        Text("•")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Text(appName)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()
                }
                
                if let ocrText = screenshot.ocrText, !ocrText.isEmpty {
                    Text(ocrText)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            // 操作按钮（悬停显示）
            if isHovered || showSelectionMode {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if screenshot.ocrText != nil {
                        ActionButton(
                            icon: "doc.on.doc",
                            color: DesignSystem.Colors.secondaryText,
                            action: onCopyText,
                            tooltip: "screenshots.context.copy_text".localized
                        )
                    }
                    
                    ActionButton(
                        icon: screenshot.isFavorite ? "star.fill" : "star",
                        color: screenshot.isFavorite ? .yellow : DesignSystem.Colors.secondaryText,
                        action: onToggleFavorite,
                        tooltip: screenshot.isFavorite ? "screenshots.context.unfavorite".localized : "screenshots.context.favorite".localized
                    )

                    ActionButton(
                        icon: "trash",
                        color: DesignSystem.Colors.error,
                        action: onDelete,
                        tooltip: "screenshots.context.delete".localized
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
            MenuContextView(
                screenshot: screenshot,
                onToggleFavorite: onToggleFavorite,
                onPrimaryAction: onPrimaryAction,
                onSecondaryAction: onSecondaryAction,
                onRename: onStartRename,
                onCopyImage: onCopyImage,
                onCopyText: onCopyText,
                onPerformOCR: onPerformOCR,
                onDelete: onDelete
            )
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

// MARK: - Context Menu View

struct MenuContextView: View {
    let screenshot: ScreenshotItem
    let onToggleFavorite: () -> Void
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void
    let onRename: () -> Void
    let onCopyImage: () -> Void
    let onCopyText: () -> Void
    let onPerformOCR: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Group {
            Button(screenshot.isFavorite ? "screenshots.context.unfavorite".localized : "screenshots.context.favorite".localized) {
                onToggleFavorite()
            }

            Divider()

            Button("screenshots.context.open".localized) {
                onPrimaryAction()
            }

            Button("screenshots.context.reveal".localized) {
                onSecondaryAction()
            }

            Button("screenshots.context.copy_image".localized) {
                onCopyImage()
            }
            
            if screenshot.ocrText != nil {
                Button("screenshots.context.copy_text".localized) {
                    onCopyText()
                }
            }
            
            if screenshot.ocrStatus != .done && screenshot.ocrStatus != .running {
                Button("screenshots.context.perform_ocr".localized) {
                    onPerformOCR()
                }
            }

            Button("screenshots.context.rename".localized) {
                onRename()
            }

            Divider()

            Button("screenshots.context.delete".localized, role: .destructive) {
                onDelete()
            }
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

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    ScreenshotsView()
        .frame(width: 800, height: 250)
}
#endif

