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
        .frame(width: 520)
    }
}
