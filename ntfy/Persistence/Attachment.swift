import Foundation
import SwiftUI
import UIKit

let attachmentTag = "Attachment"

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
    
    func asImage() -> Image? {
        guard let contentUrl = contentUrl else { return nil }
        do {
            let url = try URL(string: contentUrl).orThrow("URL \(contentUrl) is not valid")
            let data = try Data(contentsOf: url)
            let image = try UIImage(data: data).orThrow("Cannot load image from data")
            return Image(uiImage: image)
        } catch {
            Log.w(attachmentTag, "Error loading image attachment", error)
            return nil
        }
    }
}
