import Foundation

extension Attachment {
    func sizeString() -> String? {
        guard size > 0 else { return nil }
        if (size < 1000) { return "\(self.size) bytes" }
        let exp = Int(log2(Double(self.size)) / log2(1000.0))
        let unit = ["KB", "MB", "GB", "TB", "PB", "EB"][exp - 1]
        let number = Double(self.size) / pow(1000, Double(exp))
        return String(format: "%.1f %@", number, unit)
    }

    func isDownloaded() -> Bool {
        return contentUrl?.isEmpty == false
    }

    func isExpired() -> Bool {
        return TimeInterval(self.expires) < NSDate().timeIntervalSince1970
    }

    func expiresString() -> String {
        if (self.isExpired()) {
            return "Expired"
        }
        let date = NSDate(timeIntervalSince1970: TimeInterval(self.expires))
        let formatter = RelativeDateTimeFormatter()
        return "Expires \(formatter.localizedString(for: date as Date, relativeTo: Date()))"
    }
}
