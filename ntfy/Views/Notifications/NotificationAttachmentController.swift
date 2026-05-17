//
//  NotificationAttachmentController.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import SwiftUI

@MainActor
final class NotificationAttachmentController: ObservableObject {
    private var downloadTask: Task<Void, Never>?

    func startDownload(
        notification: Notification,
        attachment: MessageAttachment,
        authorizationHeader: String?,
        isAutomatic: Bool = false
    ) {
        guard downloadTask == nil else {
            return
        }
        guard let notificationID = notification.id, let remoteUrl = notification.attachmentRemoteUrl() else {
            return
        }
        let maxSize: Int64?
        if isAutomatic {
            guard Store.shared.shouldAutoDownloadAttachment(attachment) else {
                notification.skipAttachmentAutoDownload()
                return
            }
            maxSize = Store.shared.resolvedAttachmentAutoDownloadMaxSize()
        } else {
            maxSize = nil
        }

        notification.beginAttachmentDownload()
        downloadTask = Task {
            defer {
                Task { @MainActor in
                    self.downloadTask = nil
                }
            }

            do {
                let downloaded = try await AttachmentFileStore.download(
                    notificationID: notificationID,
                    remoteUrl: remoteUrl,
                    attachment: attachment,
                    authorizationHeader: authorizationHeader,
                    maxSize: maxSize,
                    onProgress: { progress in
                        Task { @MainActor in
                            notification.setAttachmentDownloadProgress(progress)
                        }
                    }
                )
                await MainActor.run {
                    notification.completeAttachmentDownload(
                        localPath: downloaded.localFileUrl.path,
                        resolvedType: downloaded.mimeType,
                        resolvedSize: downloaded.size
                    )
                }
            } catch is CancellationError {
                await MainActor.run {
                    if !notification.attachmentDownloadWasCanceled() {
                        notification.resetAttachmentDownload()
                    }
                }
            } catch AttachmentDownloadError.tooLarge {
                await MainActor.run {
                    if isAutomatic {
                        notification.skipAttachmentAutoDownload()
                    } else {
                        notification.failAttachmentDownload()
                    }
                }
            } catch {
                await MainActor.run {
                    notification.failAttachmentDownload()
                }
            }
        }
    }

    func cancelDownload(notification: Notification) {
        notification.cancelAttachmentDownload()
        downloadTask?.cancel()
        downloadTask = nil
    }

    func deleteDownloadedFile(notification: Notification) {
        guard let localFileUrl = notification.attachmentLocalFileUrl() else {
            return
        }
        try? FileManager.default.removeItem(at: localFileUrl)
        notification.markAttachmentDeleted()
    }

    deinit {
        downloadTask?.cancel()
    }
}
