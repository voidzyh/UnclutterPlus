import Combine
import Foundation

final class MainContentViewModel: ObservableObject {
    @Published var selectedTab: Int
    @Published private(set) var enabledTabs: [String]
    @Published var refreshToken: UUID = UUID()

    private let config: ConfigurationManager
    private let notificationCenter: NotificationCenter
    private var cancellables: Set<AnyCancellable> = []

    init(config: ConfigurationManager = .shared,
         notificationCenter: NotificationCenter = .default) {
        self.config = config
        self.notificationCenter = notificationCenter

        let initialTabs = config.enabledTabsOrder
        self.enabledTabs = initialTabs
        self.selectedTab = Self.resolveInitialSelection(config: config, tabs: initialTabs)

        observeConfigurationChanges()
    }

    func onAppear() {
        synchronizeWithConfiguration()
    }

    func handleAppDidBecomeActive() {
        synchronizeWithConfiguration()
    }

    func forceRefreshForLocalizationChange() {
        refreshToken = UUID()
    }

    func showPreferences() {
        PreferencesWindowManager.shared.showPreferences()
    }

    func tabIdentifier(at index: Int) -> String? {
        guard enabledTabs.indices.contains(index) else { return nil }
        return enabledTabs[index]
    }

    var hasEnabledTabs: Bool {
        !enabledTabs.isEmpty
    }

    private func observeConfigurationChanges() {
        notificationCenter.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.synchronizeWithConfiguration()
            }
            .store(in: &cancellables)
    }

    private func synchronizeWithConfiguration() {
        let currentTabs = config.enabledTabsOrder
        if currentTabs != enabledTabs {
            enabledTabs = currentTabs
        }

        adjustSelectedTab(using: currentTabs)
    }

    private func adjustSelectedTab(using tabs: [String]) {
        guard !tabs.isEmpty else {
            selectedTab = 0
            return
        }

        let defaultIndex = config.defaultTabIndex
        if defaultIndex < tabs.count {
            selectedTab = defaultIndex
        } else if selectedTab >= tabs.count {
            selectedTab = 0
        }
    }

    private static func resolveInitialSelection(config: ConfigurationManager, tabs: [String]) -> Int {
        guard !tabs.isEmpty else { return 0 }
        let defaultIndex = config.defaultTabIndex
        return defaultIndex < tabs.count ? defaultIndex : 0
    }
}
