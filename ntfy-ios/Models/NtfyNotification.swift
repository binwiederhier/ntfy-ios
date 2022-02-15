//
//  NtfyTopic.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import Foundation

class NtfyNotification: Identifiable {

    // Database Properties
    var id: String!
    var subscriptionId: Int64
    var timestamp: Int64
    var title: String
    var message: String
    var priority: Int
    var tags: String

    // Object Properties
    var emojiTags: [String] = []
    var nonEmojiTags: [String] = []

    init(id: String, subscriptionId: Int64, timestamp: Int64, title: String, message: String, priority: Int = 3, tags: String = "") {
        // Initialize values
        self.id = id
        self.subscriptionId = subscriptionId
        self.timestamp = timestamp
        self.title = title
        self.message = message
        self.priority = priority
        self.tags = tags

        // Set notification tags
        self.setTags()
    }

    func save() -> NtfyNotification {
        return Database.current.addNotification(notification: self)
    }

    func setTags() {
        // Split tags string, ignoring empty tags
        let tags = self.tags.components(separatedBy: ",").filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        for tag in tags {
            if let emoji = EmojiManager().getEmojiByAlias(alias: tag) {
                self.emojiTags.append(emoji.getUnicode())
            } else {
                self.nonEmojiTags.append(tag)
            }
        }
    }

    func displayShortDateTime() -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(self.timestamp))
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

    func timestampString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    func displayTitle() -> String {
        return self.title
    }

    func hasEmojiTags() -> Bool {
        return self.emojiTags.count > 0
    }

    func displayEmojiTags() -> String {
        var tagString = ""
        for tag in self.emojiTags {
            tagString += tag + " "
        }
        return tagString
    }

    func hasNonEmojiTags() -> Bool {
        return self.nonEmojiTags.count > 0
    }

    func displayNonEmojiTags() -> String {
        var tagString = ""
        for tag in self.nonEmojiTags {
                tagString += tag + ", "
        }
        if tagString.count > 0 {
            tagString = String(tagString.dropLast(2))
        }
        return tagString
    }
}
