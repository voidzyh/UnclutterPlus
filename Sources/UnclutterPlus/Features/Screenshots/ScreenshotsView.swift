import SwiftUI
import AppKit

struct ScreenshotsView: View {
    @StateObject private var viewModel = ScreenshotsViewModel()

    // UI State（仅纯视图状态；数据/搜索/选择/视图模式均在 ViewModel）
    @State private var columnCount: Double = 4
    @State private var dragOver = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Selection Toolbar (Contextual)
            if viewModel.isMultiSelectMode {
                selectionToolbar
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(9)
            }
            
            // Content
            if viewModel.filteredScreenshots.isEmpty {
                emptyStateView
            } else {
                contentArea
                    .zIndex(1)
            }
        }
        .background(ModernDesignSystem.shared.color(.bgCanvas))
        .onAppear {
            viewModel.onAppear()
        }
        // 使用原生 Searchable
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search screenshots...")
        // 使用原生 Toolbar
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("View Mode", selection: $viewModel.viewMode) {
                    Image(systemName: "square.grid.2x2").tag(ScreenshotsViewModel.ViewMode.grid)
                    Image(systemName: "list.bullet").tag(ScreenshotsViewModel.ViewMode.list)
                }
                .pickerStyle(.segmented)
                
                Button(action: { viewModel.toggleMultiSelectMode() }) {
                    Label(viewModel.isMultiSelectMode ? "Done" : "Select", 
                          systemImage: viewModel.isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                }
            }
        }
    }
    
    // MARK: - Content Area
    
    private var contentArea: some View {
        ScrollView {
            Group {
                switch viewModel.viewMode {
                case .grid:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: Int(columnCount)), spacing: 16) {
                        ForEach(viewModel.filteredScreenshots) { screenshot in
                            ScreenshotGridItem(
                                screenshot: screenshot,
                                isSelected: viewModel.selectedScreenshots.contains(screenshot.id),
                                showSelectionMode: viewModel.isMultiSelectMode,
                                onAction: { handleScreenshotTap(screenshot) }
                            )
                            .contextMenu { contextMenu(for: screenshot) }
                        }
                    }
                case .list:
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredScreenshots) { screenshot in
                            ScreenshotListItem(
                                screenshot: screenshot,
                                isSelected: viewModel.selectedScreenshots.contains(screenshot.id),
                                showSelectionMode: viewModel.isMultiSelectMode,
                                onAction: { handleScreenshotTap(screenshot) }
                            )
                            .contextMenu { contextMenu(for: screenshot) }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Selection Toolbar
    
    private var selectionToolbar: some View {
        HStack {
            Text("\(viewModel.selectedScreenshots.count) selected")
                .font(.caption.bold())
                .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
            
            Spacer()
            
            if !viewModel.selectedScreenshots.isEmpty {
                Button(action: {
                    let selected = viewModel.filteredScreenshots.filter { viewModel.selectedScreenshots.contains($0.id) }
                    viewModel.deleteSelectedScreenshots(selected)
                }) {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            Button("Select All") { viewModel.selectAll() }
                .buttonStyle(.link)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ModernDesignSystem.shared.color(.bgSurface))
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 48))
                .foregroundColor(ModernDesignSystem.shared.color(.textTertiary))
            
            Text("No screenshots found")
                .font(.title3)
                .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private func handleScreenshotTap(_ screenshot: ScreenshotItem) {
        if viewModel.isMultiSelectMode {
            viewModel.toggleSelection(screenshot)
        } else {
            viewModel.openScreenshot(screenshot)
        }
    }
    
    private func contextMenu(for screenshot: ScreenshotItem) -> some View {
        Group {
            Button("Open") { viewModel.openScreenshot(screenshot) }
            Button("Show in Finder") { viewModel.showInFinder(screenshot) }
            Divider()
            Button(screenshot.isFavorite ? "Unfavorite" : "Favorite") { viewModel.toggleFavorite(screenshot) }
            Button("Delete", role: .destructive) { viewModel.deleteScreenshot(screenshot) }
        }
    }
}

// MARK: - Grid Item

struct ScreenshotGridItem: View {
    let screenshot: ScreenshotItem
    let isSelected: Bool
    let showSelectionMode: Bool
    let onAction: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let thumbnail = screenshot.thumbnailImage {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 140)
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }
                
                // Overlays
                if showSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(isSelected ? .blue : .white)
                                .shadow(radius: 2)
                        }
                        Spacer()
                    }
                    .padding(8)
                } else if isHovered || screenshot.isFavorite {
                    VStack {
                        HStack {
                            if screenshot.isFavorite {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .shadow(radius: 1)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                
                // Hover overlay
                if isHovered && !showSelectionMode {
                    Color.black.opacity(0.05)
                }
            }
            .frame(height: 140)
            .background(Color.white)
            
            // Footer
            HStack {
                Text(screenshot.title)
                    .font(.caption)
                    .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
                    .lineLimit(1)
                Spacer()
                if screenshot.ocrStatus == .done {
                    Image(systemName: "text.viewfinder")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(ModernDesignSystem.shared.color(.bgSurface))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.black.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 4, x: 0, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onAction)
        .animation(ModernDesignSystem.Motion.snap, value: isHovered)
    }
}

// MARK: - List Item

struct ScreenshotListItem: View {
    let screenshot: ScreenshotItem
    let isSelected: Bool
    let showSelectionMode: Bool
    let onAction: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            if showSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            
            // Thumb
            if let thumbnail = screenshot.thumbnailImage {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 32)
                    .clipped()
                    .cornerRadius(4)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 48, height: 32)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(screenshot.title)
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.shared.color(.textPrimary))
                Text(screenshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(ModernDesignSystem.shared.color(.textSecondary))
            }
            
            Spacer()
            
            if screenshot.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.1) : (isHovered ? ModernDesignSystem.shared.color(.bgSurface) : Color.clear))
        .cornerRadius(8)
        .onTapGesture(perform: onAction)
        .onHover { isHovered = $0 }
    }
}
