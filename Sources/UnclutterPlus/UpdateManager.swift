import Foundation
import SwiftUI

// MARK: - Update Info
struct UpdateInfo: Codable {
	let version: String
	let releaseNotes: String
	let htmlURL: String
	let publishedAt: String
	
	var isNewerThanCurrent: Bool {
		return compareVersion(version, with: currentAppVersion) > 0
	}
}

// MARK: - Update Manager
final class UpdateManager: ObservableObject {
	static let shared = UpdateManager()
	
	@Published var updateInfo: UpdateInfo?
	@Published var isChecking = false
	@Published var errorMessage: String?
	
	private let latestReleaseURL = URL(string: "https://api.github.com/repos/voidzyh/UnclutterPlus/releases/latest")!
	
	private init() {}
	
	@MainActor
	func checkForUpdates(force: Bool = true) async {
		if isChecking { return }
		isChecking = true
		errorMessage = nil
		defer { isChecking = false }
		
		do {
			var request = URLRequest(url: latestReleaseURL)
			request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
			request.setValue("UnclutterPlus/\(currentAppVersion)", forHTTPHeaderField: "User-Agent")
			let (data, response) = try await URLSession.shared.data(for: request)
			guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
			switch http.statusCode {
			case 200:
				break
			case 403:
				throw NSError(domain: "Update", code: 403, userInfo: [NSLocalizedDescriptionKey: "GitHub API rate limited. Please try again later."])
			default:
				throw NSError(domain: "Update", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
			}
			let gh = try JSONDecoder().decode(GitHubRelease.self, from: data)
			let info = UpdateInfo(
				version: gh.tagName.replacingOccurrences(of: "v", with: ""),
				releaseNotes: gh.body ?? "",
				htmlURL: gh.htmlURL,
				publishedAt: gh.publishedAt
			)
			self.updateInfo = info
		} catch {
			self.errorMessage = (error as NSError).localizedDescription
		}
	}
}

// MARK: - Version Reading
var currentAppVersion: String {
	// 1) 尝试从 SPM 资源里的 Info.plist 读取（Package.swift 已 .copy("Info.plist")）
	if let url = Bundle.module.url(forResource: "Info", withExtension: "plist"),
	   let data = try? Data(contentsOf: url),
	   let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
	   let v = dict["CFBundleShortVersionString"] as? String {
		return v
	}
	// 2) 回退：从运行时 Bundle.main 读取（SPM 可执行通常为空）
	if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String { return v }
	// 3) 最终默认
	return "1.0.0"
}

// 语义化版本比较：v1>v2 返回 1；v1<v2 返回 -1；相等返回 0
private func compareVersion(_ v1: String, with v2: String) -> Int {
	let a = v1.split(separator: ".").map { Int($0) ?? 0 }
	let b = v2.split(separator: ".").map { Int($0) ?? 0 }
	let n = max(a.count, b.count)
	for i in 0..<n {
		let x = i < a.count ? a[i] : 0
		let y = i < b.count ? b[i] : 0
		if x > y { return 1 }
		if x < y { return -1 }
	}
	return 0
}

// MARK: - GitHub API model
private struct GitHubRelease: Codable {
	let tagName: String
	let body: String?
	let htmlURL: String
	let publishedAt: String
	
	enum CodingKeys: String, CodingKey {
		case tagName = "tag_name"
		case body
		case htmlURL = "html_url"
		case publishedAt = "published_at"
	}
}
