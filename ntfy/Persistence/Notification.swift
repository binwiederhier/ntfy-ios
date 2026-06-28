import Foundation

/// Extensions to make the notification easier to display
extension Notification {
    func shortDateTime() -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(self.time))
        let calendar = Calendar.current

        if calendar.isDateInYesterday(date) {
            return "yesterday"
        }

        let dateFormatter = DateFormatter()

        if calendar.isDateInToday(date) {
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short
        } else {
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .none
        }

        return dateFormatter.string(from: date)
    }
    
    func formatMessage() -> String {
        let message = message ?? ""
        if let title = title, title != "" {
            return message
        }
        let emojiTags = emojiTags()
        if !emojiTags.isEmpty {
            return emojiTags.joined(separator: "") + " " + message
        }
        return message
    }
    
    func formatTitle() -> String? {
        if let title = title, title != "" {
            let emojiTags = emojiTags()
            if !emojiTags.isEmpty {
                return emojiTags.joined(separator: "") + " " + title
            }
            return title
        }
        return nil
    }
    
    /// Whether the stored message should be rendered as Markdown (see `Message.isMarkdown`).
    var isMarkdown: Bool {
        Message.isMarkdownContentType(contentType)
    }

    func emojiTags() -> [String] {
        return parseEmojiTags(tags)
    }
    
    func nonEmojiTags() -> [String] {
        return parseNonEmojiTags(tags)
    }
    
    func actionsList() -> [Action] {
        return Actions.shared.parse(actions) ?? []
    }

    func messageAttachment() -> MessageAttachment? {
        guard let attachmentUrl = attachmentUrl, !attachmentUrl.isEmpty else {
            return nil
        }
        return MessageAttachment(
            name: attachmentName ?? "attachment",
            type: attachmentType,
            size: attachmentSize == 0 ? nil : attachmentSize,
            expires: attachmentExpires == 0 ? nil : attachmentExpires,
            url: attachmentUrl
        )
    }

    func attachmentRemoteUrl() -> URL? {
        guard let attachment = messageAttachment() else {
            return nil
        }
        return URL(string: attachment.url)
    }

    func attachmentStoredLocalFileUrl() -> URL? {
        guard let attachmentLocalPath, !attachmentLocalPath.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: attachmentLocalPath)
    }

    func attachmentLocalFileUrl() -> URL? {
        guard let url = attachmentStoredLocalFileUrl() else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    func attachmentStoredProgressState() -> AttachmentProgressState {
        AttachmentProgressState(
            storedValue: attachmentProgress,
            hasAttachment: messageAttachment() != nil,
            hasLocalFile: attachmentStoredLocalFileUrl() != nil
        )
    }

    func attachmentProgressState(overrideState: AttachmentProgressState? = nil) -> AttachmentProgressState {
        overrideState ?? attachmentStoredProgressState()
    }

    func isAttachmentDownloading(overrideState: AttachmentProgressState? = nil) -> Bool {
        attachmentProgressState(overrideState: overrideState).isDownloading
    }

    func attachmentIsExpired(referenceDate: Date = Date()) -> Bool {
        guard let expires = messageAttachment()?.expires else {
            return false
        }
        return expires < Int64(referenceDate.timeIntervalSince1970)
    }

    func attachmentStatusDescription(overrideState: AttachmentProgressState? = nil) -> String {
        guard let attachment = messageAttachment() else {
            return ""
        }
        var parts: [String] = []
        if let size = attachment.size, size > 0 {
            parts.append(formatBytes(size))
        }

        let progress = attachmentProgressState(overrideState: overrideState)
        let hasStoredLocalFile = attachmentStoredLocalFileUrl() != nil
        let deleted = !hasStoredLocalFile && (progress == .done || progress == .deleted)
        if progress == .none {
            if attachmentIsExpired() {
                parts.append("Not downloaded, expired")
            } else if let expiry = attachmentExpiryShortDateString() {
                parts.append("Not downloaded, expires \(expiry)")
            } else {
                parts.append("Not downloaded")
            }
        } else if case .progress(let percent) = progress {
            parts.append("Downloading \(percent)%")
        } else if progress == .failed {
            if attachmentIsExpired() {
                parts.append("Download failed, expired")
            } else if let expiry = attachmentExpiryShortDateString() {
                parts.append("Download failed, expires \(expiry)")
            } else {
                parts.append("Download failed")
            }
        } else if progress == .canceled {
            if attachmentIsExpired() {
                parts.append("Download canceled, expired")
            } else if let expiry = attachmentExpiryShortDateString() {
                parts.append("Download canceled, expires \(expiry)")
            } else {
                parts.append("Download canceled")
            }
        } else if progress == .skipped {
            if attachmentIsExpired() {
                parts.append("Not downloaded, expired")
            } else if let expiry = attachmentExpiryShortDateString() {
                parts.append("Not auto-downloaded, expires \(expiry)")
            } else {
                parts.append("Not auto-downloaded")
            }
        } else if deleted {
            if attachmentIsExpired() {
                parts.append("Deleted, expired")
            } else if let expiry = attachmentExpiryShortDateString() {
                parts.append("Deleted, expires \(expiry)")
            } else {
                parts.append("Deleted")
            }
        }
        return parts.joined(separator: " · ")
    }

    func notificationAttachmentSummary(overrideState: AttachmentProgressState? = nil) -> String? {
        guard let attachment = messageAttachment() else {
            return nil
        }
        var parts = [attachment.displayName()]
        if let size = attachment.size, size > 0 {
            parts.append(formatBytes(size))
        }

        let progress = attachmentProgressState(overrideState: overrideState)
        if progress == .done {
            parts.append("downloaded")
        } else if progress.isDownloading {
            parts.append("downloading")
        } else if progress == .failed {
            parts.append("download failed")
        } else if progress == .canceled {
            parts.append("download canceled")
        } else if progress == .skipped {
            parts.append("not auto-downloaded")
        } else if attachmentIsExpired() {
            parts.append("expired")
        }

        return "Attachment: " + parts.joined(separator: ", ")
    }

    private func attachmentExpiryShortDateString() -> String? {
        guard let expires = messageAttachment()?.expires else {
            return nil
        }
        let expiresDate = Date(timeIntervalSince1970: TimeInterval(expires))
        guard expiresDate > Date() else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: expiresDate)
    }

    @MainActor
    func resetAttachmentDownload() {
        attachmentProgress = AttachmentProgressState.none.persistedValue
        try? managedObjectContext?.save()
    }

    @MainActor
    func failAttachmentDownload() {
        attachmentProgress = AttachmentProgressState.failed.persistedValue
        try? managedObjectContext?.save()
    }

    @MainActor
    func cancelAttachmentDownload() {
        attachmentProgress = AttachmentProgressState.canceled.persistedValue
        try? managedObjectContext?.save()
    }

    @MainActor
    func skipAttachmentAutoDownload() {
        attachmentProgress = AttachmentProgressState.skipped.persistedValue
        try? managedObjectContext?.save()
    }

    @MainActor
    func completeAttachmentDownload(localPath: String, resolvedType: String?, resolvedSize: Int64) {
        attachmentLocalPath = localPath
        attachmentProgress = AttachmentProgressState.done.persistedValue
        if resolvedSize > 0 {
            attachmentSize = resolvedSize
        }
        if let resolvedType, !resolvedType.isEmpty {
            attachmentType = resolvedType
        }
        try? managedObjectContext?.save()
    }

    @MainActor
    func markAttachmentDeleted() {
        attachmentLocalPath = nil
        attachmentProgress = AttachmentProgressState.deleted.persistedValue
        try? managedObjectContext?.save()
    }
}

/// Renders a Markdown string down to clean plain text, dropping the formatting markers
/// (`**`, `_`, `#`, link syntax, …). Used for surfaces that cannot display rich text, such as
/// the system notification banner — APNs strips any styling from the banner, so showing the raw
/// `**markers**` there just looks broken. Falls back to the original string if parsing fails.
func markdownToPlainText(_ source: String) -> String {
    let options: AttributedString.MarkdownParsingOptions
    if #available(iOS 16.0, *) {
        options = .init(interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
    } else {
        options = .init(interpretedSyntax: .inlineOnly, failurePolicy: .returnPartiallyParsedIfPossible)
    }
    guard let attributed = try? AttributedString(markdown: source, options: options) else {
        return source
    }
    return String(attributed.characters)
}

struct MessageAttachment: Codable {
    var name: String
    var type: String?
    var size: Int64?
    var expires: Int64?
    var url: String

    func isImageAttachment() -> Bool {
        if let type = type, type.lowercased().hasPrefix("image/") {
            return true
        }
        guard let parsedUrl = URL(string: url) else {
            return false
        }
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff"]
        return imageExtensions.contains(parsedUrl.pathExtension.lowercased())
    }

    func isExpired(referenceDate: Date = Date()) -> Bool {
        guard let expires else {
            return false
        }
        return expires < Int64(referenceDate.timeIntervalSince1970)
    }

    func displayName() -> String {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        if let parsedUrl = URL(string: url) {
            let filename = parsedUrl.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !filename.isEmpty {
                return filename
            }
        }
        return "attachment"
    }

    func systemImageName() -> String {
        guard let type = type?.lowercased() else {
            return "doc"
        }
        if type.hasPrefix("image/") {
            return "photo"
        } else if type.hasPrefix("video/") {
            return "video"
        } else if type.hasPrefix("audio/") {
            return "waveform"
        } else if type == "application/pdf" {
            return "doc.richtext"
        } else if type.hasPrefix("text/") {
            return "doc.text"
        } else if type.hasPrefix("application/zip") || type.hasSuffix("compressed") {
            return "archivebox"
        } else {
            return "doc"
        }
    }
}

/// This is the "on the wire" message as it is received from the ntfy server
struct Message: Decodable {
    var id: String
    var time: Int64
    var event: String
    var topic: String
    var message: String?
    var title: String?
    var priority: Int16?
    var tags: [String]?
    var actions: [Action]?
    var click: String?
    var pollId: String?
    var attachment: MessageAttachment?
    var contentType: String?

    enum CodingKeys: String, CodingKey {
        case id, time, event, topic, message, title, priority, tags, actions, click, attachment
        case pollId = "poll_id"
        case contentType = "content_type"
    }

    /// Whether the message body should be rendered as Markdown, as indicated by the server's
    /// `content_type` (set when a message is published with the `Markdown: true` header).
    var isMarkdown: Bool {
        Message.isMarkdownContentType(contentType)
    }

    /// Returns true if the given content type denotes Markdown. Tolerates an optional charset
    /// suffix, e.g. `text/markdown; charset=utf-8`.
    static func isMarkdownContentType(_ contentType: String?) -> Bool {
        contentType?.lowercased().hasPrefix("text/markdown") ?? false
    }

    init(
        id: String,
        time: Int64,
        event: String,
        topic: String,
        message: String? = nil,
        title: String? = nil,
        priority: Int16? = nil,
        tags: [String]? = nil,
        actions: [Action]? = nil,
        click: String? = nil,
        pollId: String? = nil,
        attachment: MessageAttachment? = nil,
        contentType: String? = nil
    ) {
        self.id = id
        self.time = time
        self.event = event
        self.topic = topic
        self.message = message
        self.title = title
        self.priority = priority
        self.tags = tags
        self.actions = actions
        self.click = click
        self.pollId = pollId
        self.attachment = attachment
        self.contentType = contentType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        time = try container.decode(Int64.self, forKey: .time)
        event = try container.decode(String.self, forKey: .event)
        topic = try container.decode(String.self, forKey: .topic)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        priority = try container.decodeIfPresent(Int16.self, forKey: .priority)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        actions = try container.decodeIfPresent([Action].self, forKey: .actions)
        click = try container.decodeIfPresent(String.self, forKey: .click)
        pollId = try container.decodeIfPresent(String.self, forKey: .pollId)
        attachment = try container.decodeIfPresent(MessageAttachment.self, forKey: .attachment)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
    }
    
    func toUserInfo() -> [AnyHashable: Any] {
        // This should mimic the way that the ntfy server encodes a message.
        // See server_firebase.go for more details.
        
        var userInfo: [AnyHashable: Any] = [
            "id": id,
            "time": String(time),
            "event": event,
            "topic": topic,
            "message": message ?? "",
            "title": title ?? "",
            "priority": String(priority ?? 3),
            "tags": tags?.joined(separator: ",") ?? "",
            "actions": Actions.shared.encode(actions),
            "click": click ?? "",
            "poll_id": pollId ?? "",
            "content_type": contentType ?? ""
        ]
        if let attachment {
            userInfo["attachment_name"] = attachment.name
            userInfo["attachment_type"] = attachment.type ?? ""
            userInfo["attachment_size"] = String(attachment.size ?? 0)
            userInfo["attachment_expires"] = String(attachment.expires ?? 0)
            userInfo["attachment_url"] = attachment.url
        }
        return userInfo
    }
    
    static func from(userInfo: [AnyHashable: Any]) -> Message? {
        guard let id = userInfo["id"] as? String,
              let time = userInfo["time"] as? String,
              let event = userInfo["event"] as? String,
              let topic = userInfo["topic"] as? String,
              let timeInt = Int64(time) else {
            Log.d(Store.tag, "Unknown or irrelevant message", userInfo)
            return nil
        }
        let message = userInfo["message"] as? String
        let title = userInfo["title"] as? String
        let priority = Int16(userInfo["priority"] as? String ?? "3") ?? 3
        let tags = (userInfo["tags"] as? String ?? "").components(separatedBy: ",")
        let actions = userInfo["actions"] as? String
        let click = userInfo["click"] as? String
        let pollId = userInfo["poll_id"] as? String
        let contentType = userInfo["content_type"] as? String
        let attachmentUrl = userInfo["attachment_url"] as? String
        let attachment: MessageAttachment?
        if let attachmentUrl = attachmentUrl, !attachmentUrl.isEmpty {
            attachment = MessageAttachment(
                name: userInfo["attachment_name"] as? String ?? "attachment",
                type: userInfo["attachment_type"] as? String,
                size: Int64(userInfo["attachment_size"] as? String ?? "0").flatMap { $0 == 0 ? nil : $0 },
                expires: Int64(userInfo["attachment_expires"] as? String ?? "0").flatMap { $0 == 0 ? nil : $0 },
                url: attachmentUrl
            )
        } else {
            attachment = nil
        }
        return Message(
            id: id,
            time: timeInt,
            event: event,
            topic: topic,
            message: message,
            title: title,
            priority: priority,
            tags: tags,
            actions: Actions.shared.parse(actions),
            click: click,
            pollId: pollId,
            attachment: attachment,
            contentType: contentType
        )
    }
}

struct Action: Encodable, Decodable, Identifiable {
    var id: String
    var action: String
    var label: String
    var url: String?
    var method: String?
    var headers: [String: String]?
    var body: String?
    var clear: Bool?
}
