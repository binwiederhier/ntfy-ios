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

        let (temporaryFileUrl, response) = try await URLSession.shared.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AttachmentDownloadError.badResponse
        }

        let resolvedMimeType = attachment.type ?? httpResponse.mimeType
        let expectedSize = attachment.size ?? (response.expectedContentLength > 0 ? response.expectedContentLength : nil)
        if let maxSize, let expectedSize, expectedSize > maxSize {
            throw AttachmentDownloadError.tooLarge
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryFileUrl.path)
        let downloadedSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        if let maxSize, downloadedSize > maxSize {
            throw AttachmentDownloadError.tooLarge
        }

        onProgress?(99)
        return try storeDownloadedTemporaryFile(
            notificationID: notificationID,
            remoteUrl: remoteUrl,
            attachment: attachment,
            temporaryFileUrl: temporaryFileUrl,
            mimeType: resolvedMimeType
        )
    }

    static func existingLocalFileUrl(
        notificationID: String,
        remoteUrl: URL,
        attachment: MessageAttachment,
        mimeType: String?
    ) -> URL? {
        guard let localFileUrl = try? localFileUrl(
            notificationID: notificationID,
            attachment: attachment,
            remoteUrl: remoteUrl,
            mimeType: mimeType
        ) else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: localFileUrl.path) else {
            return nil
        }
        return localFileUrl
    }

    static func storeDownloadedTemporaryFile(
        notificationID: String,
        remoteUrl: URL,
        attachment: MessageAttachment,
        temporaryFileUrl: URL,
        mimeType: String?
    ) throws -> DownloadedAttachmentFile {
        let destinationUrl = try localFileUrl(
            notificationID: notificationID,
            attachment: attachment,
            remoteUrl: remoteUrl,
            mimeType: mimeType
        )
        try? FileManager.default.removeItem(at: destinationUrl)

        do {
            try FileManager.default.moveItem(at: temporaryFileUrl, to: destinationUrl)
        } catch {
            try FileManager.default.copyItem(at: temporaryFileUrl, to: destinationUrl)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: destinationUrl.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        return DownloadedAttachmentFile(localFileUrl: destinationUrl, size: size, mimeType: mimeType)
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
