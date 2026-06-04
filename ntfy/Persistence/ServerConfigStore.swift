import Foundation
import Security

/// Per-server request config persisted in Keychain (shared with the NSE via the app's keychain access group).
/// Values may contain bearer tokens or API keys, so Core Data is intentionally not used.
class ServerConfigStore {
    static let shared = ServerConfigStore()
    private static let tag = "ServerConfigStore"
    private static let service = "io.heckel.ntfy.serverHeaders"
    /// Must be present in `keychain-access-groups` in both ntfy and ntfyNSE entitlements.
    static let accessGroup = "group.io.heckel.ntfy"

    func getHeaders(baseUrl: String) -> [String: String] {
        let account = normalizeBaseUrl(baseUrl)
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let json = String(data: data, encoding: .utf8) else {
            return [:]
        }
        return CustomHeaders.decode(json)
    }

    func saveHeaders(baseUrl: String, headers: [String: String]) {
        let account = normalizeBaseUrl(baseUrl)
        if headers.isEmpty {
            deleteHeaders(baseUrl: account)
            return
        }
        guard let data = CustomHeaders.encode(headers).data(using: .utf8) else { return }

        let query = baseQuery(account: account)
        let updateAttrs: [String: Any] = [
            kSecValueData as String: data,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttrs as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            Log.w(ServerConfigStore.tag, "Failed to update keychain item for \(account), status \(updateStatus)")
            return
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            Log.w(ServerConfigStore.tag, "Failed to add keychain item for \(account), status \(addStatus)")
        }
    }

    func deleteHeaders(baseUrl: String) {
        let query = baseQuery(account: normalizeBaseUrl(baseUrl))
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.w(ServerConfigStore.tag, "Failed to delete keychain item, status \(status)")
        }
    }

    func allConfiguredBaseUrls() -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ServerConfigStore.service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = ServerConfigStore.accessGroup
        #endif

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
    }

    private func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ServerConfigStore.service,
            kSecAttrAccount as String: account,
        ]
        // The simulator keychain ignores access groups; setting one here makes lookups fail in dev.
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = ServerConfigStore.accessGroup
        #endif
        return query
    }
}
