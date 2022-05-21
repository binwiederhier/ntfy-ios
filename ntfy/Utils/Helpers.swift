import Foundation

func topicUrl(baseUrl: String, topic: String) -> String {
    return "\(baseUrl)/\(topic)"
}

func topicShortUrl(baseUrl: String, topic: String) -> String {
    return topicUrl(baseUrl: baseUrl, topic: topic)
        .replacingOccurrences(of: "http://", with: "")
        .replacingOccurrences(of: "https://", with: "")
}
