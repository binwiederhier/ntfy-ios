//
//  DownloadDelegate.swift
//  ntfy
//
//  Created by Alek Michelson on 5/19/26.
//

import Foundation

/// Handles attachment downloads that need early size checks, mid download cancellation and coarse progress updates that `download(for:)` cannot provide on its own.
final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, URLSessionDataDelegate {
    private let maxSize: Int64?
    private let onProgress: ((Int16) -> Void)?
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var response: URLResponse?
    private var finished = false

    init(maxSize: Int64?, onProgress: ((Int16) -> Void)?) {
        self.maxSize = maxSize
        self.onProgress = onProgress
    }

    func download(using session: URLSession, request: URLRequest) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let task = session.downloadTask(with: request)
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        if let maxSize, response.expectedContentLength > 0, response.expectedContentLength > maxSize {
            finish(session: session, result: .failure(AttachmentDownloadError.tooLarge))
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if let maxSize, totalBytesWritten > maxSize {
            finish(session: session, result: .failure(AttachmentDownloadError.tooLarge))
            downloadTask.cancel()
            return
        }

        guard totalBytesExpectedToWrite > 0 else {
            return
        }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let percent = Int16(min(99, max(0, Int(fraction * 100))))
        onProgress?(percent)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let response = response ?? downloadTask.response else {
            finish(session: session, result: .failure(AttachmentDownloadError.badResponse))
            return
        }
        do {
            let stableTemporaryUrl = try persistDownloadedFile(at: location)
            finish(session: session, result: .success((stableTemporaryUrl, response)))
        } catch {
            finish(session: session, result: .failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else {
            return
        }
        finish(session: session, result: .failure(error))
    }

    private func finish(session: URLSession, result: Result<(URL, URLResponse), Error>) {
        guard !finished else {
            return
        }
        finished = true
        session.invalidateAndCancel()
        switch result {
        case .success(let value):
            continuation?.resume(returning: value)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    private func persistDownloadedFile(at location: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = location.lastPathComponent.isEmpty ? UUID().uuidString : location.lastPathComponent
        let stableUrl = tempDir.appendingPathComponent("\(UUID().uuidString)-\(filename)")
        try? FileManager.default.removeItem(at: stableUrl)
        do {
            try FileManager.default.moveItem(at: location, to: stableUrl)
        } catch {
            try FileManager.default.copyItem(at: location, to: stableUrl)
        }
        return stableUrl
    }
}
