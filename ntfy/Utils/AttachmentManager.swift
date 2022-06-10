import Foundation
import MobileCoreServices

enum BlaError: Error {
    case bla
}

struct AttachmentManager {
    static let tag = "AttachmentManager"
    static private let attachmentDir = "attachments"
    
    static func download(url: String, id: String, completionHandler: @escaping (String?, String?, Error?) -> Void) {
        guard let url = URL(string: url) else {
            completionHandler(nil, nil, BlaError.bla)
            return
        }
        
        URLSession.shared.downloadTask(with: url) { (tempFileUrl, response, error) in
            Log.d(self.tag, "Attachment download complete", tempFileUrl, response, error)
            if let error = error {
                Log.w(self.tag, "Download attachment error", error)
                completionHandler(nil, nil, error)
                return
            }
            guard let response = response, let tempFileUrl = tempFileUrl else {
                Log.w(self.tag, "Response or temp file URL are empty")
                completionHandler(nil, nil, BlaError.bla)
                return
            }
            do {
                let fileManager = FileManager.default
                let directory = try fileManager
                    .containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup).orThrow()
                    .appendingPathComponent(attachmentDir)
                if !fileManager.fileExists(atPath: directory.path) {
                    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                }
                
                let data = try Data(contentsOf: tempFileUrl)
                let ext = data.guessExtension()

                // Rename temp file to add extension (required for it to be displayed correctly!)
                let tempFileWithExtUrl = tempFileUrl.appendingPathExtension(ext)
                try fileManager.moveItem(at: tempFileUrl, to: tempFileWithExtUrl)
                
                // Copy file
                let contentUrl = directory.appendingPathComponent(id + ext) // Images must have correct extension to be displayed correctly!
                try data.write(to: contentUrl, options: [.noFileProtection])
                
                Log.d(self.tag, "Attachment successfully saved to \(contentUrl.path)")
                completionHandler(tempFileWithExtUrl.path, contentUrl.path, nil)
            } catch {
                Log.w(self.tag, "Error saving attachment", error)
                completionHandler(nil, nil, error)
            }
        }.resume()
    }
}
