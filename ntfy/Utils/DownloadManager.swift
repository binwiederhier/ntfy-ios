import Foundation
import MobileCoreServices
import UniformTypeIdentifiers

struct DownloadManager {
    static private let attachmentDir = "attachments"
    
    static func download(id: String, data: Data, options: [NSObject : AnyObject]?) throws -> URL {
        let fileManager = FileManager.default
        let directory = try fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup).orThrow()
            .appendingPathComponent(attachmentDir)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        let fileURL = directory.appendingPathComponent(id + data.guessExtension()) // Images must have correct extension to be displayed correctly!
        try data.write(to: fileURL, options: [])
        return fileURL
    }
}
