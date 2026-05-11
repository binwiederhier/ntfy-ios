//
//  AttachmentFileStore.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import Foundation
import UniformTypeIdentifiers

/// Handles local downloads with FileManager
enum AttachmentFileStore {
   private static let attachmentsDir = "attachments"

   static func download(notification: Notification, attachment: MessageAttachment, authorizationHeader: String?) async throws -> URL {
       guard let remoteUrl = notification.attachmentRemoteUrl() else {
           throw AttachmentDownloadError.missingUrl
       }

       var request = URLRequest(url: remoteUrl)
       request.setValue(ApiService.userAgent, forHTTPHeaderField: "User-Agent")
       if let authorizationHeader {
           request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
       }

       let (tempUrl, response) = try await URLSession.shared.download(for: request)
       guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
           throw AttachmentDownloadError.badResponse
       }

       let destinationUrl = try localFileUrl(
           notification: notification,
           attachment: attachment,
           remoteUrl: remoteUrl,
           mimeType: attachment.type ?? httpResponse.mimeType
       )
       try? FileManager.default.removeItem(at: destinationUrl)
       try FileManager.default.copyItem(at: tempUrl, to: destinationUrl)
       return destinationUrl
   }

   private static func localFileUrl(notification: Notification, attachment: MessageAttachment, remoteUrl: URL, mimeType: String?) throws -> URL {
       let baseDir = FileManager.default
           .containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup)!
           .appendingPathComponent(attachmentsDir, isDirectory: true)
       try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

       let fileExtension = attachmentFileExtension(
           attachment: attachment,
           remoteUrl: remoteUrl,
           mimeType: mimeType
       )
       let baseName = sanitizeAttachmentFilename(attachment.displayName(), fallback: notification.id ?? UUID().uuidString)
       return baseDir.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
   }
}

// MARK: Error
enum AttachmentDownloadError: LocalizedError {
    case missingUrl
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingUrl:
            return "Attachment URL is missing."
        case .badResponse:
            return "Attachment download failed."
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
