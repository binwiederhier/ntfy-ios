import Foundation
import CryptoKit

func topicUrl(baseUrl: String, topic: String) -> String {
    return "\(baseUrl)/\(topic)"
}

func topicShortUrl(baseUrl: String, topic: String) -> String {
    return shortUrl(url: topicUrl(baseUrl: baseUrl, topic: topic))
}

func topicAuthUrl(baseUrl: String, topic: String) -> String {
    return "\(baseUrl)/\(topic)/auth"
}

func topicHash(baseUrl: String, topic: String) -> String {
    let data = Data(topicUrl(baseUrl: baseUrl, topic: topic).utf8)
    let digest = SHA256.hash(data: data)
    return digest.compactMap { String(format: "%02x", $0)}.joined()
}

func shortUrl(url: String) -> String {
    return url
        .replacingOccurrences(of: "http://", with: "")
        .replacingOccurrences(of: "https://", with: "")
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

func formatSize(_ size: Int64) -> String {
    if (size < 1000) { return "\(size) bytes" }
    let exp = Int(log2(Double(size)) / log2(1000.0))
    let unit = ["KB", "MB", "GB", "TB", "PB", "EB"][exp - 1]
    let number = Double(size) / pow(1000, Double(exp))
    return String(format: "%.1f %@", number, unit)
}

func timeExpired(_ expires: Int64?) -> Bool {
    guard let expires = expires else { return false }
    return expires > 0 && TimeInterval(expires) < NSDate().timeIntervalSince1970
}

extension Data {
    func mimeType() -> String {
        var b: UInt8 = 0
        self.copyBytes(to: &b, count: 1)
        switch b {
        case 0xFF:
            return "image/jpeg"
        case 0x89:
            return "image/png"
        case 0x47:
            return "image/gif"
        default:
            return "application/octet-stream"
        }
    }
    
    func guessExtension() -> String {
        switch mimeType() {
        case "image/jpeg":
            return ".jpg"
        case "image/png":
            return ".png"
        case "image/gif":
            return ".gif"
        default:
            return ".bin"
        }
    }
}

