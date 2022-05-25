import Foundation

/// Extensions to make the notification easier to display
extension Notification {
    func shortDateTime() -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(self.time))
        let calendar = Calendar.current

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let dateFormatter = DateFormatter()

        if calendar.isDateInToday(date) {
            dateFormatter.dateFormat = "h:mm a"
            dateFormatter.amSymbol = "AM"
            dateFormatter.pmSymbol = "PM"
        } else {
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
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
}

/// This is the "on the wire" message as it is received from the ntfy server
struct Message: Decodable {
    var id: String
    var time: Int64
    var message: String?
    var title: String?
    var priority: Int16?
    var tags: [String]?
}
