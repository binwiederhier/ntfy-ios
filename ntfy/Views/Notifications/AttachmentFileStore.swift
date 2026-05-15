//
//  AttachmentFileStore.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import Foundation
import UniformTypeIdentifiers

struct DownloadedAttachmentFile {
    let localFileUrl: URL
    let size: Int64
    let mimeType: String?
}

/// Handles local downloads with FileManager
enum AttachmentFileStore {
    private static let attachmentsDir = "attachments"

    static func download(
        notificationID: String,
        remoteUrl: URL,
        attachment: MessageAttachment,
        authorizationHeader: String?,
        maxSize: Int64? = nil,
        onProgress: ((Int16) -> Void)? = nil
    ) async throws -> DownloadedAttachmentFile {
        var request = URLRequest(url: remoteUrl)
        request.setValue(ApiService.userAgent, forHTTPHeaderField: "User-Agent")
        if let authorizationHeader {
            request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AttachmentDownloadError.badResponse
        }

        let resolvedMimeType = attachment.type ?? httpResponse.mimeType
        let expectedSize = attachment.size ?? (response.expectedContentLength > 0 ? response.expectedContentLength : nil)
        if let maxSize, let expectedSize, expectedSize > maxSize {
            throw AttachmentDownloadError.tooLarge
        }

        let destinationUrl = try localFileUrl(
            notificationID: notificationID,
            attachment: attachment,
            remoteUrl: remoteUrl,
            mimeType: resolvedMimeType
        )
        try? FileManager.default.removeItem(at: destinationUrl)
        FileManager.default.createFile(atPath: destinationUrl.path, contents: nil)

        let handle = try FileHandle(forWritingTo: destinationUrl)
        var totalBytes: Int64 = 0
        var buffer = Data()
        var lastProgress: Int16 = ATTACHMENT_PROGRESS_NONE

        do {
            for try await byte in bytes {
                try Task.checkCancellation()

                buffer.append(byte)
                totalBytes += 1

                if buffer.count >= 64 * 1024 {
                    try handle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                }

                if let maxSize, totalBytes > maxSize {
                    throw AttachmentDownloadError.tooLarge
                }

                guard let expectedSize, expectedSize > 0 else {
                    continue
                }
                let progress = Int16(min(99, Int((Double(totalBytes) / Double(expectedSize)) * 100)))
                if progress != lastProgress {
                    lastProgress = progress
                    onProgress?(progress)
                }
            }

            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
            }
            try handle.close()
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: destinationUrl)
            throw error
        }

        return DownloadedAttachmentFile(localFileUrl: destinationUrl, size: totalBytes, mimeType: resolvedMimeType)
    }

    private static func localFileUrl(notificationID: String, attachment: MessageAttachment, remoteUrl: URL, mimeType: String?) throws -> URL {
        let baseDir = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup)!
            .appendingPathComponent(attachmentsDir, isDirectory: true)
        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        let fileExtension = attachmentFileExtension(
            attachment: attachment,
            remoteUrl: remoteUrl,
            mimeType: mimeType
        )
        let displayName = attachment.displayName()
        let baseNameSource = URL(fileURLWithPath: displayName).deletingPathExtension().lastPathComponent
        let baseName = sanitizeAttachmentFilename(baseNameSource, fallback: "attachment")
        let sanitizedNotificationID = sanitizeAttachmentFilename(notificationID, fallback: UUID().uuidString)
        return baseDir
            .appendingPathComponent("\(sanitizedNotificationID)-\(baseName)")
            .appendingPathExtension(fileExtension)
    }
}

// MARK: Error
enum AttachmentDownloadError: LocalizedError {
    case missingUrl
    case badResponse
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .missingUrl:
            return "Attachment URL is missing."
        case .badResponse:
            return "Attachment download failed."
        case .tooLarge:
            return "Attachment is larger than the auto-download limit."
        }
    }
}

// MARK: Helpers
extension AttachmentFileStore {
    static private func attachmentFileExtension(attachment: MessageAttachment, remoteUrl: URL, mimeType: String?) -> String {
        let attachmentName = attachment.displayName()
        let nameExtension = URL(fileURLWithPath: attachmentName).pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nameExtension.isEmpty {
            return nameExtension
        }

        let pathExtension = remoteUrl.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pathExtension.isEmpty {
            return pathExtension
        }

        if let mimeType,
           let type = UTType(mimeType: mimeType),
           let preferredExtension = type.preferredFilenameExtension {
            return preferredExtension
        }
        return "bin"
    }

    static private func sanitizeAttachmentFilename(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? fallback : trimmed
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let components = baseName.components(separatedBy: invalidCharacters)
        let sanitized = components.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? fallback : sanitized
    }
}
