//
//  NtfyTopic.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import Foundation

class NtfyNotification: Identifiable {

    // Properties
    var id: String!
    var subscriptionId: Int64
    var timestamp: Int64
    var title: String
    var message: String
    var priority: Int
    var tags: String

    init(id: String, subscriptionId: Int64, timestamp: Int64, title: String, message: String, priority: Int = 3, tags: String = "") {
        // Initialize values
        self.id = id
        self.subscriptionId = subscriptionId
        self.timestamp = timestamp
        self.title = title
        self.message = message
        self.priority = priority
        self.tags = tags
    }

    func save() -> NtfyNotification {
        return Database.current.addNotification(notification: self)
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

    func displayTags() -> String {
        var tagString = ""
        let tags = self.tags.components(separatedBy: ",")
        for tag in tags {
            tagString += EmojiManager().getEmojiByAlias(alias: tag)?.getUnicode() ?? "" + " "
        }
        return tagString
    }
}
