import Foundation
import Security

/// Keychain 封装 —— 项目首个密钥安全存储设施。
///
/// 用于存储 AI API Key 等敏感凭证（而非明文 UserDefaults）。
/// 仅支持 String 的简单读写；服务名按用途区分。
enum KeychainWrapper {

    /// 存储字符串到 Keychain。
    /// - Parameters:
    ///   - value: 要存储的明文字符串（为 nil 时删除该项）
    ///   - account: 账户标识（如 "ai.apikey"）
    ///   - service: 服务名（默认 "UnclutterPlus"）
    @discardableResult
    static func set(_ value: String?, forAccount account: String, service: String = "UnclutterPlus") -> Bool {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // 先删除已存在项
        SecItemDelete(baseQuery as CFDictionary)

        guard let value, let data = value.data(using: .utf8) else {
            // value == nil 表示删除，已完成
            return true
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        // 仅在解锁时可访问，且不持久化到 iCloud Keychain
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// 从 Keychain 读取字符串。
    static func get(forAccount account: String, service: String = "UnclutterPlus") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// 删除 Keychain 中的项。
    @discardableResult
    static func delete(forAccount account: String, service: String = "UnclutterPlus") -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
