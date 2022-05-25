import Foundation

func topicUrl(baseUrl: String, topic: String) -> String {
    return "\(baseUrl)/\(topic)"
}

func topicShortUrl(baseUrl: String, topic: String) -> String {
    return topicUrl(baseUrl: baseUrl, topic: topic)
        .replacingOccurrences(of: "http://", with: "")
        .replacingOccurrences(of: "https://", with: "")
}

func parseAllTags(_ tags: String?) -> [String] {
    return (tags?.components(separatedBy: ",") ?? [])
        .filter { $0.trimmingCharacters(in: [" "]) != "" }
}

func parseEmojiTags(_ tags: String?) -> [String] {
    var emojiTags: [String] = []
    for tag in parseAllTags(tags) {
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
