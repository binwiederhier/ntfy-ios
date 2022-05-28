import Foundation
import CryptoKit

func topicUrl(baseUrl: String, topic: String) -> String {
    return "\(baseUrl)/\(topic)"
}

func topicShortUrl(baseUrl: String, topic: String) -> String {
    return topicUrl(baseUrl: baseUrl, topic: topic)
        .replacingOccurrences(of: "http://", with: "")
        .replacingOccurrences(of: "https://", with: "")
}

func topicHash(baseUrl: String, topic: String) -> String {
    let data = Data(topicUrl(baseUrl: baseUrl, topic: topic).utf8)
    let digest = SHA256.hash(data: data)
    return digest.compactMap { String(format: "%02x", $0)}.joined()
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
