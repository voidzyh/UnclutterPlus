import Foundation
import MarkdownUI
import Splash

// MARK: - Notification Names
extension Notification.Name {
    static let menuBarIconVisibilityChanged = Notification.Name("menuBarIconVisibilityChanged")
}

// MARK: - Markdown Theme Options
enum MarkdownThemeOption: String, CaseIterable {
    case basic
    case docC
    case gitHub
    
    var displayName: String {
        switch self {
        case .basic: return "Basic"
        case .docC: return "DocC"
        case .gitHub: return "GitHub"
        }
    }
    
    func toMarkdownUITheme() -> MarkdownUI.Theme {
        switch self {
        case .basic: return .basic
        case .docC: return .docC
        case .gitHub: return .gitHub
        }
    }
}

// MARK: - Code Highlight Theme Options
enum CodeHighlightThemeOption: String, CaseIterable {
    case sunset
    case midnight
    case presentation
    case wwdc18
    case sundellsColors
    
    var displayName: String {
        switch self {
        case .sunset: return "Sunset"
        case .midnight: return "Midnight"
        case .presentation: return "Presentation"
        case .wwdc18: return "WWDC 2018"
        case .sundellsColors: return "Sundell's Colors"
        }
    }
    
    func toSplashTheme(fontSize: CGFloat) -> Splash.Theme {
        switch self {
        case .sunset:
            return Splash.Theme.sunset(withFont: Splash.Font(size: fontSize))
        case .midnight:
            return Splash.Theme.midnight(withFont: Splash.Font(size: fontSize))
        case .presentation:
            return Splash.Theme.presentation(withFont: Splash.Font(size: fontSize))
        case .wwdc18:
            return Splash.Theme.wwdc18(withFont: Splash.Font(size: fontSize))
        case .sundellsColors:
            return Splash.Theme.sundellsColors(withFont: Splash.Font(size: fontSize))
        }
    }
}

// MARK: - Preferences Model
final class Preferences: ObservableObject {
    static let shared = Preferences()
    
    @Published var markdownTheme: MarkdownThemeOption {
        didSet { save() }
    }
    @Published var codeHighlightTheme: CodeHighlightThemeOption {
        didSet { save() }
    }
    @Published var enableBaseURL: Bool {
        didSet { save() }
    }
    @Published var baseURLString: String {
        didSet { save() }
    }
    // Mouse scroll mode: natural vs traditional (trackpad always natural)
    @Published var mouseScrollMode: MouseScrollMode {
        didSet { save() }
    }
    
    // Notes auto-save interval (in seconds)
    @Published var notesAutoSaveInterval: Double {
        didSet { save() }
    }
    
    // Menu bar icon visibility
    @Published var showMenuBarIcon: Bool {
        didSet { 
            save()
            NotificationCenter.default.post(name: .menuBarIconVisibilityChanged, object: nil)
        }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "MarkdownThemeOption"),
           let value = MarkdownThemeOption(rawValue: raw) {
            markdownTheme = value
        } else {
            markdownTheme = .gitHub
        }
        if let raw = defaults.string(forKey: "CodeHighlightThemeOption"),
           let value = CodeHighlightThemeOption(rawValue: raw) {
            codeHighlightTheme = value
        } else {
            codeHighlightTheme = .sunset
        }
        enableBaseURL = defaults.bool(forKey: "MarkdownEnableBaseURL")
        baseURLString = defaults.string(forKey: "MarkdownBaseURLString") ?? ""

        if let raw = defaults.string(forKey: "MouseScrollMode"),
           let value = MouseScrollMode(rawValue: raw) {
            mouseScrollMode = value
        } else {
            mouseScrollMode = .natural
        }
        
        // Load auto-save interval (default: 2.0 seconds)
        let savedInterval = defaults.double(forKey: "NotesAutoSaveInterval")
        notesAutoSaveInterval = savedInterval > 0 ? savedInterval : 2.0
        
        // Load menu bar icon visibility (default: true)
        if defaults.object(forKey: "ShowMenuBarIcon") != nil {
            showMenuBarIcon = defaults.bool(forKey: "ShowMenuBarIcon")
        } else {
            showMenuBarIcon = true
        }
    }
    
    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(markdownTheme.rawValue, forKey: "MarkdownThemeOption")
        defaults.set(codeHighlightTheme.rawValue, forKey: "CodeHighlightThemeOption")
        defaults.set(enableBaseURL, forKey: "MarkdownEnableBaseURL")
        defaults.set(baseURLString, forKey: "MarkdownBaseURLString")
        defaults.set(mouseScrollMode.rawValue, forKey: "MouseScrollMode")
        defaults.set(notesAutoSaveInterval, forKey: "NotesAutoSaveInterval")
        defaults.set(showMenuBarIcon, forKey: "ShowMenuBarIcon")
    }
}

// MARK: - Mouse Scroll Mode
enum MouseScrollMode: String, CaseIterable {
    case natural
    case traditional
    
    var displayName: String {
        switch self {
        case .natural: return "Natural (like trackpad)"
        case .traditional: return "Traditional (legacy wheel)"
        }
    }
}
