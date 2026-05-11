//
//  NotificationAttachmentController.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

// TODO: This will be converted to the @Observable macro at some point :)

import SwiftUI

@MainActor
final class NotificationAttachmentController: ObservableObject {
    @Published var isDownloading = false
    @Published var errorMessage: String?

    private var downloadTask: Task<Void, Never>?

    func startDownload(notification: Notification, attachment: MessageAttachment, authorizationHeader: String?) {
        guard downloadTask == nil else {
            return
        }
        errorMessage = nil
        isDownloading = true

        downloadTask = Task {
            defer {
                Task { @MainActor in
                    self.isDownloading = false
                    self.downloadTask = nil
                }
            }

            do {
                let localFileUrl = try await AttachmentFileStore.download(
                    notification: notification,
                    attachment: attachment,
                    authorizationHeader: authorizationHeader
                )
                await MainActor.run {
                    notification.setAttachmentLocalPath(localFileUrl.path)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
    }

    func deleteDownloadedFile(notification: Notification) {
        guard let localFileUrl = notification.attachmentLocalFileUrl() else {
            return
        }
        try? FileManager.default.removeItem(at: localFileUrl)
        notification.setAttachmentLocalPath(nil)
    }
}


