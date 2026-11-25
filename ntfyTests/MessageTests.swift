import Foundation
import Testing
@testable import ntfy

struct MessageTests {
    /// Mirrors the string-only payload the ntfy server sends through Firebase (see server_firebase.go).
    private func payload(_ overrides: [String: String] = [:]) -> [AnyHashable: Any] {
        var userInfo: [String: String] = [
            "id": "abc123",
            "time": "1700000000",
            "event": "message",
            "topic": "alerts",
            "message": "Disk is full",
            "title": "Backup",
            "priority": "4",
            "tags": "warning,backup",
            "click": "https://example.com"
        ]
        userInfo.merge(overrides) { _, new in new }
        return userInfo
    }

    @Test func parsesMessagePayload() throws {
        let message = try #require(Message.from(userInfo: payload()))
        #expect(message.id == "abc123")
        #expect(message.time == 1_700_000_000)
        #expect(message.event == "message")
        #expect(message.topic == "alerts")
        #expect(message.message == "Disk is full")
        #expect(message.title == "Backup")
        #expect(message.priority == 4)
        #expect(message.tags == ["warning", "backup"])
        #expect(message.click == "https://example.com")
        #expect(message.attachment == nil)
    }

    @Test func parsesPollRequestPayload() throws {
        let userInfo: [AnyHashable: Any] = [
            "id": "p1", "time": "1700000000", "event": "poll_request", "topic": "abcdef", "poll_id": "msg42"
        ]
        let message = try #require(Message.from(userInfo: userInfo))
        #expect(message.event == "poll_request")
        #expect(message.pollId == "msg42")
        #expect(message.priority == 3, "Missing priority defaults to 3")
    }

    @Test(arguments: ["id", "time", "event", "topic"])
    func rejectsPayloadMissingRequiredField(field: String) {
        var userInfo = payload()
        userInfo.removeValue(forKey: field)
        #expect(Message.from(userInfo: userInfo) == nil)
    }

    @Test func rejectsNonNumericTime() {
        #expect(Message.from(userInfo: payload(["time": "yesterday"])) == nil)
    }

    @Test func invalidPriorityFallsBackToDefault() throws {
        let message = try #require(Message.from(userInfo: payload(["priority": "urgent"])))
        #expect(message.priority == 3)
    }

    @Test func parsesAttachmentAndTreatsZeroAsMissing() throws {
        let message = try #require(Message.from(userInfo: payload([
            "attachment_name": "photo.jpg",
            "attachment_type": "image/jpeg",
            "attachment_size": "2048",
            "attachment_expires": "0",
            "attachment_url": "https://example.com/file/photo.jpg"
        ])))
        let attachment = try #require(message.attachment)
        #expect(attachment.name == "photo.jpg")
        #expect(attachment.size == 2048)
        #expect(attachment.expires == nil)
        #expect(attachment.isImageAttachment())
    }

    @Test func roundTripsThroughUserInfo() throws {
        let original = try #require(Message.from(userInfo: payload([
            "attachment_name": "report.pdf",
            "attachment_type": "application/pdf",
            "attachment_url": "https://example.com/file/report.pdf"
        ])))
        let copy = try #require(Message.from(userInfo: original.toUserInfo()))
        #expect(copy.id == original.id)
        #expect(copy.time == original.time)
        #expect(copy.title == original.title)
        #expect(copy.priority == original.priority)
        #expect(copy.tags == original.tags)
        #expect(copy.attachment?.url == original.attachment?.url)
        #expect(copy.attachment?.type == "application/pdf")
    }

    @Test func parsesOnlySupportedActions() throws {
        let json = """
        [{"id":"1","action":"view","label":"Open","url":"https://example.com"},
         {"id":"2","action":"broadcast","label":"Ignored"},
         {"id":"3","action":"http","label":"Ack","url":"https://example.com/ack","method":"POST"}]
        """
        let message = try #require(Message.from(userInfo: payload(["actions": json])))
        #expect(message.actions?.map(\.id) == ["1", "3"])
    }

    @Test func malformedActionsAreIgnored() throws {
        let message = try #require(Message.from(userInfo: payload(["actions": "not json"])))
        #expect(message.actions == nil)
    }

    @Test func attachmentFallsBackToUrlFilename() {
        let attachment = MessageAttachment(name: " ", type: nil, size: nil, expires: nil, url: "https://example.com/a/b.png")
        #expect(attachment.displayName() == "b.png")
        #expect(attachment.isImageAttachment())
    }

    @Test func attachmentExpiry() {
        let now = Date(timeIntervalSince1970: 1_000)
        let expired = MessageAttachment(name: "a", type: nil, size: nil, expires: 999, url: "https://x/a")
        let valid = MessageAttachment(name: "a", type: nil, size: nil, expires: 1_001, url: "https://x/a")
        #expect(expired.isExpired(referenceDate: now))
        #expect(!valid.isExpired(referenceDate: now))
    }
}
