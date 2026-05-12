import Foundation

enum CustomHeaders {
    static let keyRegex = "^[A-Za-z0-9-]+$"

    static func isValidKey(_ key: String) -> Bool {
        return key.range(of: keyRegex, options: .regularExpression) != nil
    }

    static func encode(_ headers: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(headers),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func decode(_ raw: String?) -> [String: String] {
        guard let raw = raw,
              !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
