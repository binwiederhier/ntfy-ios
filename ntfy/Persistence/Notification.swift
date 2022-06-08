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
    
    func allTags() -> [String] {
        return parseAllTags(tags)
    }
    
    func emojiTags() -> [String] {
        return parseEmojiTags(tags)
    }
    
    func nonEmojiTags() -> [String] {
        return parseNonEmojiTags(tags)
    }
    
    func actionsList() -> [MessageAction] {
        return Actions.shared.parse(actions) ?? []
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
    var actions: [MessageAction]?
    var click: String?
    var pollId: String?
    var attachment: MessageAttachment?
    
    func toUserInfo() -> [AnyHashable: Any] {
        // This should mimic the way that the ntfy server encodes a message.
        // See server_firebase.go for more details.
        
        return [
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
            "attachment_name": attachment?.name ?? "",
            "attachment_url": attachment?.url ?? "",
            "attachment_size": attachment?.size ?? "",
            "attachment_type": attachment?.type ?? "",
            "attachment_expires": attachment?.expires ?? "",
        ]
    }
    
    static func from(userInfo: [AnyHashable: Any]) -> Message? {
        guard let id = userInfo["id"] as? String,
              let time = userInfo["time"] as? String,
              let event = userInfo["event"] as? String,
              let topic = userInfo["topic"] as? String,
              let timeInt = Int64(time),
              let message = userInfo["message"] as? String else {
            Log.d(Store.tag, "Unknown or irrelevant message", userInfo)
            return nil
        }
        let title = userInfo["title"] as? String
        let priority = Int16(userInfo["priority"] as? String ?? "3") ?? 3
        let tags = (userInfo["tags"] as? String ?? "").components(separatedBy: ",")
        let actions = userInfo["actions"] as? String
        let click = userInfo["click"] as? String
        let pollId = userInfo["poll_id"] as? String
        var attachment: MessageAttachment?
        if let attachmentName = userInfo["attachment_name"] as? String, let attachmentUrl = userInfo["attachment_url"] as? String {
            attachment = MessageAttachment(
                name: attachmentName,
                url: attachmentUrl,
                type: userInfo["attachment_type"] as? String ?? "",
                size: Int64(userInfo["attachment_size"] as? String ?? ""), // default is invalid number -> nil
                expires: Int64(userInfo["attachment_expires"] as? String ?? "") // default is invalid number -> nil
            )
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

struct MessageAction: Encodable, Decodable, Identifiable {
    var id: String
    var action: String
    var label: String
    var url: String?
    var method: String?
    var headers: [String: String]?
    var body: String?
    var clear: Bool?
}

struct MessageAttachment: Decodable {
    var name: String
    var url: String
    var type: String?
    var size: Int64?
    var expires: Int64?
}
