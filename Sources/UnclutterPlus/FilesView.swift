import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @StateObject private var fileManager = TempFileManager()
    @State private var dragOver = false
    
    var body: some View {
        VStack {
            if fileManager.files.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Drop files here")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Drag and drop files to store them temporarily")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 文件列表
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(fileManager.files) { file in
                            FileItemView(file: file) {
                                fileManager.removeFile(file)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(dragOver ? Color.accentColor.opacity(0.1) : Color.clear)
                .stroke(dragOver ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleFileDrop(providers)
        }
    }
    
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        fileManager.addFile(from: url)
                    }
                }
            }
        }
        return true
    }
}

struct FileItemView: View {
    let file: TempFile
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 文件图标
            Image(systemName: file.systemImage)
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
            
            // 文件名
            Text(file.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
            
            // 文件大小
            Text(file.sizeString)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .contextMenu {
            Button("Open") {
                NSWorkspace.shared.open(file.url)
            }
            
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
            }
            
            Divider()
            
            Button("Remove", role: .destructive) {
                onRemove()
            }
        }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(file.url)
        }
    }
}

#Preview {
    FilesView()
        .frame(width: 800, height: 250)
}