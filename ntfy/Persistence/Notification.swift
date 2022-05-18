//
//  Notification.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/16/22.
//

import Foundation

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
}

struct Message: Decodable {
    var id: String
    var time: Int64
    var message: String?
    var title: String?
}
