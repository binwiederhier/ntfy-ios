import Foundation
import MobileCoreServices

enum BlaError: Error {
    case bla
}

struct AttachmentManager {
    static let tag = "AttachmentManager"
    static private let attachmentDir = "attachments"
    
    static func download(url: String, id: String, completionHandler: @escaping (String?, Error?) -> Void) {
        guard let url = URL(string: url) else {
            completionHandler(nil, BlaError.bla)
            return
        }
        
        URLSession.shared.downloadTask(with: url) { (tempFileUrl, response, error) in
            Log.d(self.tag, "Attachment download complete", tempFileUrl, response, error)
            if let error = error {
                Log.w(self.tag, "Download attachment error", error)
                completionHandler(nil, error)
                return
            }
            guard let response = response, let tempFileUrl = tempFileUrl else {
                Log.w(self.tag, "Response or temp file URL are empty")
                completionHandler(nil, BlaError.bla)
                return
            }
            do {
                let fileManager = FileManager.default
                let directory = try fileManager
                    .containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup).orThrow()
                    //.appendingPathComponent(attachmentDir)
                if !fileManager.fileExists(atPath: directory.path) {
                    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                }
                let data = try Data(contentsOf: tempFileUrl)
                let targetUrl = directory.appendingPathComponent(id + data.guessExtension()) // Images must have correct extension to be displayed correctly!
                try? directory.disableFileProtection()
                try? targetUrl.disableFileProtection()
                try data.write(to: targetUrl, options: [.noFileProtection])
                //try fileManager.copyItem(at: tempFileUrl.absoluteURL, to: targetUrl)
                
                Log.d(self.tag, "Attachment successfully saved to \(targetUrl.path)")
                completionHandler(targetUrl.path, nil)
            } catch {
                Log.w(self.tag, "Error saving attachment", error)
                completionHandler(nil, error)
            }
        }.resume()
    }
}
