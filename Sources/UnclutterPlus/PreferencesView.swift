import SwiftUI

struct PreferencesView: View {
    @ObservedObject var prefs = Preferences.shared
    
    var body: some View {
        Form {
            Section("Markdown") {
                Picker("Theme", selection: $prefs.markdownTheme) {
                    ForEach(MarkdownThemeOption.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                Picker("Code Highlight", selection: $prefs.codeHighlightTheme) {
                    ForEach(CodeHighlightThemeOption.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
            }
            
            Section("Notes") {
                HStack {
                    Text("Auto-save interval:")
                    Spacer()
                    Text(String(format: "%.1fs", prefs.notesAutoSaveInterval))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                Slider(value: $prefs.notesAutoSaveInterval, in: 0.5...10.0, step: 0.5)
            }
            
            Section(footer: Text("How long to wait before automatically saving notes while typing.").font(.footnote)) {
                EmptyView()
            }
            
            Section("Mouse & Trackpad") {
                Picker("Mouse Scroll", selection: $prefs.mouseScrollMode) {
                    ForEach(MouseScrollMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Text("Trackpad gestures always use Natural.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Section("Appearance") {
                Toggle("Show menu bar icon", isOn: $prefs.showMenuBarIcon)
                
                if !prefs.showMenuBarIcon {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("When menu bar icon is hidden:", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text("• Click Settings button in main window")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text("• Right-click Dock icon for menu")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text("• Swipe down at top edge to show window")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Base URL") {
                Toggle("Enable Base URL", isOn: $prefs.enableBaseURL)
                TextField("https://example.com/assets/", text: $prefs.baseURLString)
                    .disabled(!prefs.enableBaseURL)
            }
            
            Section(footer: Text("Base URL 用于解析 Markdown 相对链接与图片地址").font(.footnote)) {
                EmptyView()
            }
        }
        .padding(20)
        .frame(width: 520, height: 500)
    }
}
