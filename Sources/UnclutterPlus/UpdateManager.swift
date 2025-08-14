import Foundation
import SwiftUI

// MARK: - Current App Version
var currentAppVersion: String {
    return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
}

var currentBuildNumber: String {
    return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
}

// MARK: - Version Comparison Helper
private func compareVersion(_ version1: String, with version2: String) -> Int {
    let components1 = version1.components(separatedBy: ".").compactMap { Int($0) }
    let components2 = version2.components(separatedBy: ".").compactMap { Int($0) }
    
    let maxLength = max(components1.count, components2.count)
    
    for i in 0..<maxLength {
        let v1 = i < components1.count ? components1[i] : 0
        let v2 = i < components2.count ? components2[i] : 0
        
        if v1 > v2 { return 1 }
        if v1 < v2 { return -1 }
    }
    
    return 0 // 版本相等
}

// MARK: - Update Info Model
struct UpdateInfo: Codable {
    let version: String
    let buildNumber: String
    let releaseNotes: String
    let downloadURL: String
    let releaseDate: String
    let isRequired: Bool
    let minOSVersion: String
    
    var displayVersion: String {
        return "v\(version)"
    }
    
    var isNewerThanCurrent: Bool {
        return compareVersion(version, with: currentAppVersion) > 0
    }
}

// MARK: - Update Manager
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var updateInfo: UpdateInfo?
    @Published var isCheckingForUpdates = false
    @Published var lastCheckDate: Date?
    @Published var errorMessage: String?
    
    // 配置
    private let updateCheckURL = "https://api.github.com/repos/voidzyh/UnclutterPlus/releases/latest"
    private let appBundleID = "com.voidzyh.UnclutterPlus"
    
    // 用户偏好设置
    @AppStorage("update.autoCheck") var autoCheckForUpdates: Bool = true
    @AppStorage("update.checkInterval") var checkInterval: TimeInterval = 24 * 60 * 60 // 24小时
    @AppStorage("update.lastCheckDate") private var lastCheckDateString: String = ""
    @AppStorage("update.skipVersion") var skipVersion: String = ""
    
    private init() {
        loadLastCheckDate()
    }
    
    // MARK: - Public Methods
    
    /// 检查更新
    func checkForUpdates(force: Bool = false) async {
        // 检查是否需要检查更新
        if !force && !shouldCheckForUpdates() {
            return
        }
        
        await MainActor.run {
            isCheckingForUpdates = true
            errorMessage = nil
        }
        
        do {
            let info = try await fetchUpdateInfo()
            await MainActor.run {
                self.updateInfo = info
                self.lastCheckDate = Date()
                self.saveLastCheckDate()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
        
        await MainActor.run {
            isCheckingForUpdates = false
        }
    }
    
    /// 自动检查更新（如果启用且满足条件）
    func autoCheckForUpdates() async {
        guard autoCheckForUpdates else { return }
        
        if shouldCheckForUpdates() {
            await checkForUpdates()
        }
    }
    
    /// 跳过当前版本
    func skipCurrentVersion() {
        if let info = updateInfo {
            skipVersion = info.version
            updateInfo = nil
        }
    }
    
    /// 下载更新
    func downloadUpdate() {
        guard let info = updateInfo,
              let url = URL(string: info.downloadURL) else { return }
        
        NSWorkspace.shared.open(url)
    }
    
    /// 重置跳过版本
    func resetSkipVersion() {
        skipVersion = ""
    }
    
    // MARK: - Private Methods
    
    private func shouldCheckForUpdates() -> Bool {
        // 如果强制检查，则跳过时间检查
        if let lastCheck = lastCheckDate {
            let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
            return timeSinceLastCheck >= checkInterval
        }
        return true
    }
    
    private func fetchUpdateInfo() async throws -> UpdateInfo {
        guard let url = URL(string: updateCheckURL) else {
            throw UpdateError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw UpdateError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // 解析GitHub API响应
        let githubRelease = try JSONDecoder().decode(GitHubRelease.self, from: data)
        
        // 转换为我们的UpdateInfo格式
        return UpdateInfo(
            version: githubRelease.tagName.replacingOccurrences(of: "v", with: ""),
            buildNumber: githubRelease.tagName,
            releaseNotes: githubRelease.body ?? "",
            downloadURL: githubRelease.htmlURL,
            releaseDate: githubRelease.publishedAt,
            isRequired: false, // GitHub API不提供此信息，默认为false
            minOSVersion: "10.15" // 默认最低macOS版本
        )
    }
    
    private func loadLastCheckDate() {
        if !lastCheckDateString.isEmpty {
            let formatter = ISO8601DateFormatter()
            lastCheckDate = formatter.date(from: lastCheckDateString)
        }
    }
    
    private func saveLastCheckDate() {
        if let date = lastCheckDate {
            let formatter = ISO8601DateFormatter()
            lastCheckDateString = formatter.string(from: date)
        }
    }
    
    // MARK: - Version Comparison
    
    // MARK: - GitHub API Models
    private struct GitHubRelease: Codable {
        let tagName: String
        let name: String
        let body: String?
        let htmlURL: String
        let publishedAt: String
        let prerelease: Bool
        
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case body
            case htmlURL = "html_url"
            case publishedAt = "published_at"
            case prerelease
        }
    }
    
    // MARK: - Update Errors
    enum UpdateError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int)
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "update.error.invalid_url".localized
            case .invalidResponse:
                return "update.error.invalid_response".localized
            case .httpError(let statusCode):
                return String(format: "update.error.http".localized, statusCode)
            case .decodingError:
                return "update.error.decoding".localized
            }
        }
    }
}
