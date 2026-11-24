import Testing
@testable import ntfy

struct HelpersTests {
    @Test(arguments: [
        ("https://ntfy.sh", "https://ntfy.sh"),
        ("https://ntfy.sh/", "https://ntfy.sh"),
        ("https://ntfy.sh///", "https://ntfy.sh"),
        ("  https://example.com/ \n", "https://example.com")
    ])
    func normalizeBaseUrlTrimsWhitespaceAndSlashes(input: String, expected: String) {
        #expect(normalizeBaseUrl(input) == expected)
    }

    @Test func topicUrlJoinsNormalizedBaseUrlAndTopic() {
        #expect(topicUrl(baseUrl: "https://ntfy.sh/", topic: "alerts") == "https://ntfy.sh/alerts")
        #expect(topicAuthUrl(baseUrl: "https://ntfy.sh", topic: "alerts") == "https://ntfy.sh/alerts/auth")
    }

    @Test(arguments: [
        ("https://ntfy.sh", "alerts", "ntfy.sh/alerts"),
        ("http://10.0.0.1:8080", "x", "10.0.0.1:8080/x")
    ])
    func topicShortUrlStripsScheme(baseUrl: String, topic: String, expected: String) {
        #expect(topicShortUrl(baseUrl: baseUrl, topic: topic) == expected)
    }

    @Test func topicHashIsStableSha256OfTopicUrl() {
        let hash = topicHash(baseUrl: "https://example.com", topic: "alerts")
        #expect(hash.count == 64)
        #expect(hash.allSatisfy { $0.isHexDigit })
        // Trailing slashes must not change the hash, or self-hosted subscriptions stop matching.
        #expect(hash == topicHash(baseUrl: "https://example.com/", topic: "alerts"))
        #expect(hash != topicHash(baseUrl: "https://example.com", topic: "other"))
    }

    @Test func firebaseTopicUsesPlainTopicOnlyForDefaultServer() {
        #expect(firebaseTopic(baseUrl: Config.appBaseUrl, topic: "alerts") == "alerts")
        #expect(firebaseTopic(baseUrl: Config.appBaseUrl + "/", topic: "alerts") == "alerts")

        let selfHosted = "https://example.com"
        #expect(firebaseTopic(baseUrl: selfHosted, topic: "alerts") == topicHash(baseUrl: selfHosted, topic: "alerts"))
    }

    @Test(arguments: [
        ("a,b, ,,c", ["a", "b", "c"]),
        ("", []),
        (nil, [])
    ] as [(String?, [String])])
    func parseAllTagsDropsBlankEntries(input: String?, expected: [String]) {
        #expect(parseAllTags(input) == expected)
    }

    @Test func emojiTagsAreSplitFromPlainTags() {
        #expect(parseEmojiTags("tada,backup") == ["🎉"])
        #expect(parseNonEmojiTags("tada,backup") == ["backup"])
    }
}
