//
//  NtfyAttachment.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 2/20/22.
//

import Foundation

class NtfyAttachment: Codable {
    var id: Int64!
    var name: String
    var type: String
    var size: Int64
    var expires: Int64
    var url: String
    var contentUrl: String

    init(id: Int64, name: String, type: String = "", size: Int64 = 0, expires: Int64 = 0, url: String = "", contentUrl: String = "") {
        self.id = id
        self.name = name
        self.type = type
        self.size = size
        self.expires = expires
        self.url = url
        self.contentUrl = contentUrl
    }

    enum CodingKeys: String, CodingKey {
        case name, type, size, expires, url
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.size = try container.decode(Int64.self, forKey: .size)
        self.expires = try container.decode(Int64.self, forKey: .expires)
        self.url = try container.decode(String.self, forKey: .url)
        self.contentUrl = ""
    }

    func save() {
        Database.current.updateAttachment(attachment: self)
    }

    func sizeString() -> String {
        if (self.size < 1000) { return "\(self.size) B" }
        let exp = Int(log2(Double(self.size)) / log2(1000.0))
        let unit = ["KB", "MB", "GB", "TB", "PB", "EB"][exp - 1]
        let number = Double(self.size) / pow(1000, Double(exp))
        return String(format: "%.1f %@", number, unit)
    }

    func isDownloaded() -> Bool {
        return !contentUrl.isEmpty
    }

    func downloadedString() -> String {
        return self.isDownloaded() ? "Downloaded" : "Not downloaded"
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

    func download() {
        print("Attempting attachment download")
        guard let attachmentUrl = URL(string: self.url) else { return }
        print("Attachment URL: \(attachmentUrl)")
        URLSession.shared.downloadTask(with: attachmentUrl) { (data, response, error) in
            print("Attachment download complete")
            print("Response: \(response)")
            print("Data: \(data)")
            if let error = error {
                print("Download attachment error: \(error)")
                return
            }

            if let response = response,
               let data = data {
                let fileManager = FileManager.default
                // Get the App Group path, which is accessed by both the app and the notification service extension
                if let path = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.ntfy") {
                    guard let fileUrl = URL(string: "\(path)/downloads/\(response.hash)") else { return }
                    do {
                        let parentPath = fileUrl.deletingLastPathComponent()
                        if !fileManager.fileExists(atPath: parentPath.path) {
                            try fileManager.createDirectory(atPath: parentPath.path, withIntermediateDirectories: true, attributes: nil)
                        }
                        try fileManager.moveItem(at: data.absoluteURL, to: fileUrl)
                        self.contentUrl = fileUrl.path
                        self.save()
                        print(self.contentUrl)
                        print("Attachment saved to \(fileUrl.path)")
                    } catch {
                        print("Error saving attachment: \(error)")
                    }
                }
            }
        }.resume()
    }
}
