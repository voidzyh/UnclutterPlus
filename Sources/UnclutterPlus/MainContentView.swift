import SwiftUI

struct MainContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择器
            HStack(spacing: 0) {
                TabButton(title: "Files", systemImage: "folder", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "Clipboard", systemImage: "doc.on.clipboard", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabButton(title: "Notes", systemImage: "note.text", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Divider()
            
            // 内容区域
            Group {
                switch selectedTab {
                case 0:
                    FilesView()
                case 1:
                    ClipboardView()
                case 2:
                    NotesView()
                default:
                    FilesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(radius: 20)
        )
        .padding(8)
    }
}

struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainContentView()
        .frame(width: 800, height: 300)
}