import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var prefs = Preferences.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var config = ConfigurationManager.shared
    @State private var refreshID = UUID()
    
    private enum PreferenceCategory: String, CaseIterable, Identifiable {
        case general
        case features
        case storage
        case integration
        case advanced

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .general: return "preferences.tab.general"
            case .features: return "preferences.tab.features"
            case .storage: return "preferences.tab.storage"
            case .integration: return "preferences.tab.integration"
            case .advanced: return "preferences.tab.advanced"
            }
        }

        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .features: return "square.stack.3d.up"
            case .storage: return "externaldrive"
            case .integration: return "sparkles"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }
    
    @State private var selectedCategory: PreferenceCategory = .general
    @State var aiAPIKeyInput: String = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧分类列表
            List(selection: $selectedCategory) {
                ForEach(PreferenceCategory.allCases) { category in
                    Label(category.titleKey.localized, systemImage: category.systemImage)
                        .tag(category)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 220)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // 右侧详情
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedCategory {
                    case .general:
                        generalSettingsTab
                    case .features:
                        featuresSettingsTab
                    case .storage:
                        storageSettingsTab
                    case .integration:
                        integrationSettingsTab
                    case .advanced:
                        advancedSettingsTab
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 760, height: 520)
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
    }
}
