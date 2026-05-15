import Foundation

let ATTACHMENT_PROGRESS_NONE: Int16 = -1
let ATTACHMENT_PROGRESS_INDETERMINATE: Int16 = -2
let ATTACHMENT_PROGRESS_FAILED: Int16 = -3
let ATTACHMENT_PROGRESS_DELETED: Int16 = -4
let ATTACHMENT_PROGRESS_DONE: Int16 = 100

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
    
    func allTags() -> [String] {
        return parseAllTags(tags)
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

    func attachmentImageUrl() -> URL? {
        guard let attachment = messageAttachment(), let attachmentUrl = attachmentRemoteUrl() else {
            return nil
        }
        guard attachment.isImageAttachment() else {
            return nil
        }
        return attachmentUrl
    }

    func attachmentRemoteUrl() -> URL? {
        guard let attachment = messageAttachment() else {
            return nil
        }
        return URL(string: attachment.url)
    }

    func attachmentLocalFileUrl() -> URL? {
        guard let attachmentLocalPath, !attachmentLocalPath.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: attachmentLocalPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    func attachmentDetailText() -> String {
        guard let attachment = messageAttachment() else {
            return ""
        }
        var parts: [String] = []
        if let type = attachment.type, !type.isEmpty {
            parts.append(type)
        }
        if let size = attachment.size, size > 0 {
            parts.append(formatBytes(size))
        }
        return parts.joined(separator: " · ")
    }

    func attachmentProgressValue() -> Int16 {
        if attachmentLocalFileUrl() != nil {
            return ATTACHMENT_PROGRESS_DONE
        }
        if attachmentProgress == 0, messageAttachment() != nil {
            return ATTACHMENT_PROGRESS_NONE
        }
        return attachmentProgress
    }

    func isAttachmentDownloading() -> Bool {
        let progress = attachmentProgressValue()
        return progress == ATTACHMENT_PROGRESS_INDETERMINATE || (0..<ATTACHMENT_PROGRESS_DONE).contains(progress)
    }

    func attachmentDownloadFailed() -> Bool {
        attachmentProgressValue() == ATTACHMENT_PROGRESS_FAILED
    }

    func attachmentWasDeleted() -> Bool {
        attachmentProgressValue() == ATTACHMENT_PROGRESS_DELETED
    }

    func attachmentIsExpired(referenceDate: Date = Date()) -> Bool {
        guard let expires = messageAttachment()?.expires else {
            return false
        }
        return expires < Int64(referenceDate.timeIntervalSince1970)
    }

    func attachmentStatusDescription() -> String {
        guard let attachment = messageAttachment() else {
            return ""
        }
        var parts: [String] = []
        if let size = attachment.size, size > 0 {
            parts.append(formatBytes(size))
        }

        let progress = attachmentProgressValue()
        let exists = attachmentLocalFileUrl() != nil
        let deleted = !exists && (progress == ATTACHMENT_PROGRESS_DONE || progress == ATTACHMENT_PROGRESS_DELETED)
        if progress == ATTACHMENT_PROGRESS_NONE {
            if attachmentIsExpired() {
                parts.append("Not downloaded, expired")
            } else if let expiry = attachmentExpiryShortDateString() {
                parts.append("Not downloaded, expires \(expiry)")
            } else {
                parts.append("Not downloaded")
            }
        } else if progress == ATTACHMENT_PROGRESS_INDETERMINATE {
            parts.append("Downloading")
        } else if (0..<ATTACHMENT_PROGRESS_DONE).contains(progress) {
            parts.append("Downloading \(progress)%")
        } else if progress == ATTACHMENT_PROGRESS_FAILED {
            if attachmentIsExpired() {
                parts.append("Download failed, expired")
            } else if let expiry = attachmentExpiryShortDateString() {
                parts.append("Download failed, expires \(expiry)")
            } else {
                parts.append("Download failed")
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

    func notificationAttachmentSummary() -> String? {
        guard let attachment = messageAttachment() else {
            return nil
        }
        var parts = [attachment.displayName()]
        if let size = attachment.size, size > 0 {
            parts.append(formatBytes(size))
        }

        let progress = attachmentProgressValue()
        if progress == ATTACHMENT_PROGRESS_DONE {
            parts.append("downloaded")
        } else if progress == ATTACHMENT_PROGRESS_INDETERMINATE || (0..<ATTACHMENT_PROGRESS_DONE).contains(progress) {
            parts.append("downloading")
        } else if progress == ATTACHMENT_PROGRESS_FAILED {
            parts.append("download failed")
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
    func setAttachmentLocalPath(_ localPath: String?) {
        attachmentLocalPath = localPath
        try? managedObjectContext?.save()
    }

    @MainActor
    func beginAttachmentDownload() {
        attachmentProgress = ATTACHMENT_PROGRESS_INDETERMINATE
        try? managedObjectContext?.save()
    }

    @MainActor
    func setAttachmentDownloadProgress(_ progress: Int16) {
        attachmentProgress = progress
        try? managedObjectContext?.save()
    }

    @MainActor
    func resetAttachmentDownload() {
        attachmentProgress = ATTACHMENT_PROGRESS_NONE
        try? managedObjectContext?.save()
    }

    @MainActor
    func failAttachmentDownload() {
        attachmentProgress = ATTACHMENT_PROGRESS_FAILED
        try? managedObjectContext?.save()
    }

    @MainActor
    func completeAttachmentDownload(localPath: String, resolvedType: String?, resolvedSize: Int64) {
        attachmentLocalPath = localPath
        attachmentProgress = ATTACHMENT_PROGRESS_DONE
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
        attachmentProgress = ATTACHMENT_PROGRESS_DELETED
        try? managedObjectContext?.save()
    }
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

    enum CodingKeys: String, CodingKey {
        case id, time, event, topic, message, title, priority, tags, actions, click, attachment
        case pollId = "poll_id"
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
        attachment: MessageAttachment? = nil
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
            "poll_id": pollId ?? ""
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
            attachment: attachment
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
