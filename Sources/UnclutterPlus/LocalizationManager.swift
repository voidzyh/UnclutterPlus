import Foundation
import SwiftUI

// MARK: - Language Options
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case traditionalChinese = "zh-Hant"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "简体中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        case .traditionalChinese: return "繁體中文"
        }
    }
    
    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en")
        case .chinese: return Locale(identifier: "zh-Hans")
        case .japanese: return Locale(identifier: "ja")
        case .korean: return Locale(identifier: "ko")
        case .french: return Locale(identifier: "fr")
        case .german: return Locale(identifier: "de")
        case .spanish: return Locale(identifier: "es")
        case .traditionalChinese: return Locale(identifier: "zh-Hant")
        }
    }
}

// MARK: - Localization Manager
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguage")
            // 发送通知以更新UI
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }
    
    private init() {
        // 加载保存的语言设置，如果没有则使用系统语言
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage"),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            // 根据系统语言设置默认语言
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            if preferredLanguage.contains("zh-Hans") {
                currentLanguage = .chinese
            } else if preferredLanguage.contains("zh-Hant") || preferredLanguage.contains("zh-TW") || preferredLanguage.contains("zh-HK") {
                currentLanguage = .traditionalChinese
            } else if preferredLanguage.contains("ja") {
                currentLanguage = .japanese
            } else if preferredLanguage.contains("ko") {
                currentLanguage = .korean
            } else if preferredLanguage.contains("fr") {
                currentLanguage = .french
            } else if preferredLanguage.contains("de") {
                currentLanguage = .german
            } else if preferredLanguage.contains("es") {
                currentLanguage = .spanish
            } else {
                currentLanguage = .english
            }
        }
    }
    
    // 获取本地化字符串
    func localizedString(_ key: String) -> String {
        // 对于可执行文件，直接查找资源包中的本地化文件
        let executableURL = Bundle.main.executableURL!
        let bundleURL = executableURL.deletingLastPathComponent().appendingPathComponent("UnclutterPlus_UnclutterPlus.bundle")
        
        // 尝试从资源bundle加载
        if let resourceBundle = Bundle(url: bundleURL) {
            if let path = resourceBundle.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
               let languageBundle = Bundle(path: path) {
                let localizedString = languageBundle.localizedString(forKey: key, value: key, table: "Localizable")
                if localizedString != key {
                    return localizedString
                }
            }
        }
        
        // 尝试从主bundle加载
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            let localizedString = languageBundle.localizedString(forKey: key, value: key, table: "Localizable")
            if localizedString != key {
                return localizedString
            }
        }
        
        print("Warning: Missing localization for key: \(key)")
        // 移除 "tab." 等前缀，返回更友好的默认值
        let components = key.split(separator: ".")
        if let lastComponent = components.last {
            // 将下划线转换为空格并首字母大写
            let processed = lastComponent.replacingOccurrences(of: "_", with: " ")
            return processed.capitalized
        }
        return key
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - SwiftUI Helper
struct LocalizedText: View {
    let key: String
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    init(_ key: String) {
        self.key = key
    }
    
    var body: some View {
        Text(localizationManager.localizedString(key))
    }
}

// MARK: - String Extension for Convenience
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }
}