import SwiftUI

struct PreferencesView: View {
    @ObservedObject var prefs = Preferences.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @State private var refreshID = UUID()
    
    var body: some View {
        Form {
            Section("preferences.section.language".localized) {
                Picker("preferences.language.select".localized, selection: $localizationManager.currentLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Text("preferences.language.restart_required".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Section("preferences.section.markdown".localized) {
                Picker("preferences.markdown.theme".localized, selection: $prefs.markdownTheme) {
                    ForEach(MarkdownThemeOption.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                Picker("preferences.markdown.code_highlight".localized, selection: $prefs.codeHighlightTheme) {
                    ForEach(CodeHighlightThemeOption.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
            }
            
            Section("preferences.section.notes".localized) {
                HStack {
                    Text("preferences.notes.autosave_interval".localized)
                    Spacer()
                    Text(String(format: "%.1fs", prefs.notesAutoSaveInterval))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                Slider(value: $prefs.notesAutoSaveInterval, in: 0.5...10.0, step: 0.5)
            }
            
            Section(footer: Text("preferences.notes.autosave_help".localized).font(.footnote)) {
                EmptyView()
            }
            
            Section("preferences.section.mouse_trackpad".localized) {
                Picker("preferences.mouse.scroll_mode".localized, selection: $prefs.mouseScrollMode) {
                    ForEach(MouseScrollMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Text("preferences.trackpad.help".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Section("preferences.section.appearance".localized) {
                Toggle("preferences.appearance.show_menubar".localized, isOn: $prefs.showMenuBarIcon)
                
                if !prefs.showMenuBarIcon {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("preferences.appearance.menubar_hidden_info".localized, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text("preferences.appearance.menubar_hidden_tip1".localized)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text("preferences.appearance.menubar_hidden_tip2".localized)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text("preferences.appearance.menubar_hidden_tip3".localized)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("preferences.section.base_url".localized) {
                Toggle("preferences.base_url.enable".localized, isOn: $prefs.enableBaseURL)
                TextField("https://example.com/assets/", text: $prefs.baseURLString)
                    .disabled(!prefs.enableBaseURL)
            }
            
            Section(footer: Text("preferences.base_url.help".localized).font(.footnote)) {
                EmptyView()
            }
        }
        .padding(20)
        .frame(width: 520, height: 500)
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
    }
}
