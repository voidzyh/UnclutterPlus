import SwiftUI

struct ClipboardView: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @State private var searchText = ""
    
    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardManager.items
        } else {
            return clipboardManager.items.filter { item in
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
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search clipboard history...", text: $searchText)
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            if filteredItems.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "No clipboard history" : "No matching items")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "Copy something to see it here" : "Try a different search term")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 剪贴板项目列表
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredItems) { item in
                            ClipboardItemView(item: item) {
                                clipboardManager.copyToClipboard(item)
                            } onDelete: {
                                clipboardManager.removeItem(item)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // 底部工具栏
            HStack {
                Button("Clear All") {
                    clipboardManager.clearAll()
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("\(filteredItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

struct ClipboardItemView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: item.systemImage)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            // 内容预览
            VStack(alignment: .leading, spacing: 4) {
                switch item.content {
                case .text(let text):
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                
                case .image:
                    HStack {
                        Text("Image")
                            .fontWeight(.medium)
                        Spacer()
                    }
                
                case .file(let url):
                    HStack {
                        Text(url.lastPathComponent)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                
                // 时间戳
                Text(item.timestamp.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy to clipboard")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            onCopy()
        }
        .contextMenu {
            Button("Copy") {
                onCopy()
            }
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    ClipboardView()
        .frame(width: 800, height: 250)
}
#endif