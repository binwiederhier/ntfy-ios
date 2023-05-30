import Foundation
import SwiftUI
import UIKit

let attachmentTag = "Attachment"

extension Attachment {
    func sizeString() -> String? {
        guard size > 0 else { return nil }
        return formatSize(size)
    }

    func isDownloaded() -> Bool {
        return contentUrl?.isEmpty == false
    }

    func isExpired() -> Bool {
        return timeExpired(self.expires)
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
        let url = URL(fileURLWithPath: contentUrl)
        do {
            let data = try Data(contentsOf: url)
            let image = try UIImage(data: data).orThrow("Cannot load image from data")
            Log.d(attachmentTag, "Successfulluy loaded image attachment from \(contentUrl), URL: \(url)")
            return Image(uiImage: image)
        } catch {
            Log.w(attachmentTag, "Error loading image attachment from \(contentUrl), URL: \(url)", error)
            return nil
        }
    }
}
