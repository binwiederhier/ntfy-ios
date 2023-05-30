import Foundation
import MobileCoreServices

enum DownloadError: Error {
    case invalidUrlOrDirectory
    case maxSizeReached
    case unexpectedResponse
}

struct AttachmentManager {
    static private let tag = "AttachmentManager"
    static private let attachmentDir = "attachments"
    static private let bufferSize = 131072 // 128 KB
    
    static func download(url: String, id: String, maxLength: Int64, timeout: TimeInterval, completionHandler: @escaping (URL?, Error?) -> Void) {
        if #available(iOS 15, *) {
            downloadStream(url: url, id: id, maxLength: maxLength, timeout: timeout, completionHandler: completionHandler)
        } else {
            downloadNoStream(url: url, id: id, maxLength: maxLength, timeout: timeout, completionHandler: completionHandler)
        }
    }
    
    @available(iOS 15, *)
    private static func downloadStream(url: String, id: String, maxLength: Int64, timeout: TimeInterval, completionHandler: @escaping (URL?, Error?) -> Void) {
        Task {
            Log.d(self.tag, "Streaming \(url)")
            guard let url = URL(string: url), let attachmentDir = createAttachmentDir() else {
                completionHandler(nil, DownloadError.invalidUrlOrDirectory)
                return
            }
            do {
                let sessionConfig = URLSessionConfiguration.default
                sessionConfig.timeoutIntervalForRequest = timeout
                sessionConfig.timeoutIntervalForResource = timeout

                let session = URLSession.init(configuration: sessionConfig)
                let (asyncBytes, urlResponse) = try await session.bytes(from: url)
                let expectedLength = urlResponse.expectedContentLength
                
                // Fail fast: If Content-Length header set and it's >maxLength, fail
                if maxLength > 0 && expectedLength > maxLength {
                    throw DownloadError.maxSizeReached
                }
                
                // Open temporary file handle
                let fileManager = FileManager.default
                var contentUrl = attachmentDir.appendingPathComponent(id)
                try? fileManager.removeItem(atPath: contentUrl.path)
                fileManager.createFile(atPath: contentUrl.path, contents: nil)
                let fileHandle = try FileHandle(forWritingTo: contentUrl)
                Log.d(self.tag, "Writing to \(contentUrl.path)")

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
                        try fileHandle.write(contentsOf: data)
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
                    try fileHandle.write(contentsOf: data)
                }
                try fileHandle.close()
                Log.d(self.tag, "Download complete, written \(formatSize(written))")

                // Rename temp file to add extension (required for it to be displayed correctly!)
                let contentUrlWithExt = URL(fileURLWithPath: contentUrl.path + ext)
                if contentUrl != contentUrlWithExt {
                    try? fileManager.removeItem(at: contentUrlWithExt)
                    try fileManager.moveItem(at: contentUrl, to: contentUrlWithExt)
                    contentUrl = contentUrlWithExt
                }
                
                Log.d(self.tag, "Attachment successfully saved to \(contentUrl.path)")
                completionHandler(contentUrl, nil)
            } catch {
                Log.w(self.tag, "Error when streaming \(url)", error)
                completionHandler(nil, error)
            }
        }
    }
    
    private static func downloadNoStream(url: String, id: String, maxLength: Int64, timeout: TimeInterval, completionHandler: @escaping (URL?, Error?) -> Void) {
        guard let url = URL(string: url), let attachmentDir = createAttachmentDir() else {
            completionHandler(nil, DownloadError.invalidUrlOrDirectory)
            return
        }
        
        // FIXME: Do a HEAD request first to bail out early
        
        URLSession.shared.downloadTask(with: url) { (tempFileUrl, response, error) in
            Log.d(self.tag, "Attachment download complete", tempFileUrl, response, error)
            guard
                let response = response,
                let httpResponse = response as? HTTPURLResponse,
                let tempFileUrl = tempFileUrl,
                (200...299).contains(httpResponse.statusCode),
                error == nil
            else {
                Log.w(self.tag, "Attachment download failed")
                completionHandler(nil, DownloadError.unexpectedResponse)
                return
            }
            do {
                let fileManager = FileManager.default
                let data = try Data(contentsOf: tempFileUrl)
                let ext = data.guessExtension()
                
                // Sad sad late fail: Bail out if t
                if maxLength > 0 && data.count > maxLength {
                    throw DownloadError.maxSizeReached
                }
               
                // Rename temp file to target URL (with extension, required for it to be displayed correctly!)
                let contentUrl = attachmentDir.appendingPathComponent(id + ext)
                try fileManager.moveItem(at: tempFileUrl, to: contentUrl)
                
                Log.d(self.tag, "Attachment successfully saved to \(contentUrl.path)")
                completionHandler(contentUrl, nil)
            } catch {
                Log.w(self.tag, "Error saving attachment", error)
                completionHandler(nil, error)
            }
        }.resume()
    }
    
    
    private static func createAttachmentDir() -> URL? {
        do {
            let fileManager = FileManager.default
            let directory = try fileManager
                .containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup).orThrow()
                .appendingPathComponent(attachmentDir)
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            return directory
        } catch {
            Log.e(tag, "Unable to get or create attachment directory", error)
            return nil
        }
    }
}
