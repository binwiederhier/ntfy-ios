import Foundation
import CryptoKit

struct NtfyDeepLink: Equatable {
    let baseUrl: String
    let topic: String

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "ntfy",
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        let pathSegments = components.path
            .split(separator: "/", omittingEmptySubsequences: false)
            .dropFirst()
        guard pathSegments.count == 1, let topic = pathSegments.first, !topic.isEmpty else {
            return nil
        }

        let secureValue = components.queryItems?
            .first { $0.name == "secure" }?
            .value?
            .lowercased()
        let secure = secureValue != "false" && secureValue != "0"
        let defaultPort = secure ? 443 : 80

        var baseComponents = URLComponents()
        baseComponents.scheme = secure ? "https" : "http"
        baseComponents.host = host
        if components.port != defaultPort {
            baseComponents.port = components.port
        }

        guard let baseUrl = baseComponents.string else {
            return nil
        }
        self.baseUrl = baseUrl
        self.topic = String(topic)
    }
}

func topicUrl(baseUrl: String, topic: String) -> String {
    return "\(normalizeBaseUrl(baseUrl))/\(topic)"
}

func topicShortUrl(baseUrl: String, topic: String) -> String {
    return shortUrl(url: topicUrl(baseUrl: baseUrl, topic: topic))
}

func topicAuthUrl(baseUrl: String, topic: String) -> String {
    return "\(normalizeBaseUrl(baseUrl))/\(topic)/auth"
}

func topicHash(baseUrl: String, topic: String) -> String {
    let data = Data(topicUrl(baseUrl: normalizeBaseUrl(baseUrl), topic: topic).utf8)
    let digest = SHA256.hash(data: data)
    return digest.compactMap { String(format: "%02x", $0)}.joined()
}

func firebaseTopic(baseUrl: String, topic: String) -> String {
    return normalizeBaseUrl(baseUrl) == normalizeBaseUrl(Config.appBaseUrl)
        ? topic
        : topicHash(baseUrl: baseUrl, topic: topic)
}

func normalizeBaseUrl(_ baseUrl: String) -> String {
    var normalized = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    while normalized.hasSuffix("/") {
        normalized.removeLast()
    }
    return normalized
}

func shortUrl(url: String) -> String {
    return url
        .replacingOccurrences(of: "http://", with: "")
        .replacingOccurrences(of: "https://", with: "")
}

func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

func parseAllTags(_ tags: String?) -> [String] {
    return (tags?.components(separatedBy: ",") ?? [])
        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
}

func parseEmojiTags(_ tags: String?) -> [String] {
    return parseEmojiTags(parseAllTags(tags))
}

func parseEmojiTags(_ tags: [String]?) -> [String] {
    guard let tags = tags else { return [] }
    var emojiTags: [String] = []
    for tag in tags {
        if let emoji = EmojiManager.shared.getEmojiByAlias(alias: tag) {
            emojiTags.append(emoji.getUnicode())
        }
    }
    return emojiTags
}

func parseNonEmojiTags(_ tags: String?) -> [String] {
    return parseAllTags(tags)
        .filter { EmojiManager.shared.getEmojiByAlias(alias: $0) == nil }
}
