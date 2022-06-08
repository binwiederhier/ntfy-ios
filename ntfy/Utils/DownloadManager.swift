import Foundation


struct DownloadManager {
    static private let attachmentDir = "attachments"
    
    static func download(attachmentId: String, data: Data, options: [NSObject : AnyObject]?) -> URL? {
        let fileManager = FileManager.default
        if let directory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup) {
            do {
                let newDirectory = directory.appendingPathComponent(attachmentDir)
                if !fileManager.fileExists(atPath: newDirectory.path) {
                    try? fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: true, attributes: nil)
                }
                let fileURL = newDirectory.appendingPathComponent(attachmentId)
                do {
                    try data.write(to: fileURL, options: [])
                } catch {
                    print("Unable to load data: \(error)")
                }
                return fileURL
            } catch let error {
                print("Error: \(error)")
            }
        }
        return nil
    }
}
