import Foundation
import MobileCoreServices

enum DownloadError: Error {
    case invalidUrl
    case maxSizeReached
    case unexpectedResponse
}

struct AttachmentManager {
    static let tag = "AttachmentManager"
    static private let attachmentDir = "attachments"
    static private let bufferSize = 131072 // 128 KB
    
    static func download(url: String, id: String, completionHandler: @escaping (String?, String?, Error?) -> Void) {
        guard let url = URL(string: url) else {
            completionHandler(nil, nil, DownloadError.invalidUrl)
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
                completionHandler(nil, nil, DownloadError.unexpectedResponse)
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
    
    static func downloadWithMaxSize(url: String, id: String, maxLength: Int64, completionHandler: @escaping (String?, String?, Error?) -> Void) {
        if #available(iOS 15, *) {
            stream(url: url, id: id, maxLength: maxLength, completionHandler: completionHandler)
        } else {
            
        }
    }
    
    @available(iOS 15, *)
    private static func stream(url: String, id: String, maxLength: Int64, completionHandler: @escaping (String?, String?, Error?) -> Void) {
        Task {
            Log.d(self.tag, "Streaming \(url)")
            guard let url = URL(string: url) else {
                completionHandler(nil, nil, DownloadError.invalidUrl)
                return
            }
            
            do {
                let (asyncBytes, urlResponse) = try await URLSession.shared.bytes(from: url)
                let expectedLength = urlResponse.expectedContentLength
                
                // Fail fast: If Content-Length header set and it's >maxLength, fail
                if expectedLength > maxLength {
                    //throw DownloadError.maxSizeReached
                }
                
                // Open temporary file handle
                let fileManager = FileManager.default
                let tempFileUrl = fileManager.temporaryDirectory.appendingPathComponent(id)
                fileManager.createFile(atPath: tempFileUrl.path, contents: nil)
                let tempFileHandle = try FileHandle(forWritingTo: tempFileUrl)
                
                // Stream to file
                var ext = ""
                var data = Data()
                var written = Int64(0)
                var lastProgress = NSDate().timeIntervalSince1970
                for try await byte in asyncBytes {
                    data.append(byte)
                    written += 1
                    if data.count == bufferSize {
                        if ext.isEmpty {
                            ext = data.guessExtension()
                        }
                        try tempFileHandle.write(contentsOf: data)
                        data = Data()
                        
                        if NSDate().timeIntervalSince1970 - lastProgress >= 1 {
                            if expectedLength > 0 {
                                Log.d(self.tag, "Download progress: \(formatSize(written)) (\(Double(written) / Double(expectedLength) * 100.0)%)")
                            } else {
                                Log.d(self.tag, "Download progress: \(formatSize(written))")
                            }
                            lastProgress = NSDate().timeIntervalSince1970
                        }
                    }
                }
                if !data.isEmpty {
                    if ext.isEmpty {
                        ext = data.guessExtension()
                    }
                    try tempFileHandle.write(contentsOf: data)
                }
                try tempFileHandle.close()
                Log.d(self.tag, "Download progress: \(formatSize(written)) (100%)")

                // Rename temp file to add extension (required for it to be displayed correctly!)
                let tempFileWithExtUrl = tempFileUrl.appendingPathExtension(ext)
                try fileManager.moveItem(at: tempFileUrl, to: tempFileWithExtUrl)
                
                // Copy file
               // let contentUrl = directory.appendingPathComponent(id + ext) // Images must have correct extension to be displayed correctly!
               // try data.write(to: contentUrl, options: [.noFileProtection])
                
                //Log.d(self.tag, "Attachment successfully saved to \(contentUrl.path)")*/
                //completionHandler(tempFileWithExtUrl.path, contentUrl.path, nil)
                completionHandler(tempFileWithExtUrl.path, tempFileWithExtUrl.path, nil)
            } catch {
                Log.w(self.tag, "Error when streaming \(url)", error)
                completionHandler(nil, nil, error)
            }
        }
    }
    
    private static func fakeStream(url: String, id: String, completionHandler: @escaping (String?, String?, Error?) -> Void) async {
        
    }
}
