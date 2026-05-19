//
//  NotificationAttachmentController.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import CoreData
import SwiftUI

@MainActor
final class NotificationAttachmentController: ObservableObject {
    private var downloadTask: Task<Void, Never>?
    @Published private var activeNotificationObjectID: NSManagedObjectID?
    @Published private var transientProgressState: AttachmentProgressState?

    func progressState(for notification: Notification) -> AttachmentProgressState {
        if activeNotificationObjectID == notification.objectID, let transientProgressState {
            return transientProgressState
        }
        return notification.attachmentStoredProgressState()
    }

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
        let logPrefix = isAutomatic ? "automatic" : "manual"
        let maxSize: Int64?
        if isAutomatic {
            guard Store.shared.shouldAutoDownloadAttachment(attachment) else {
                Log.d("NotificationAttachmentController", "Skipping \(logPrefix) attachment download for \(notificationID): policy denied")
                notification.skipAttachmentAutoDownload()
                return
            }
            maxSize = Store.shared.resolvedAttachmentAutoDownloadMaxSize()
        } else {
            maxSize = nil
        }

        Log.d("NotificationAttachmentController", "Starting \(logPrefix) attachment download for \(notificationID) from \(remoteUrl.absoluteString)")
        setTransientProgressState(.progress(0), for: notification)
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
                            self.setTransientProgressState(.progress(progress), for: notification)
                        }
                    }
                )
                await MainActor.run {
                    Log.d("NotificationAttachmentController", "Completed \(logPrefix) attachment download for \(notificationID) at \(downloaded.localFileUrl.path)")
                    notification.completeAttachmentDownload(
                        localPath: downloaded.localFileUrl.path,
                        resolvedType: downloaded.mimeType,
                        resolvedSize: downloaded.size
                    )
                    self.clearTransientProgressState(for: notification)
                }
            } catch is CancellationError {
                await MainActor.run {
                    Log.d("NotificationAttachmentController", "Canceled \(logPrefix) attachment download for \(notificationID)")
                    if notification.attachmentStoredProgressState() != .canceled {
                        notification.resetAttachmentDownload()
                    }
                    self.clearTransientProgressState(for: notification)
                }
            } catch AttachmentDownloadError.tooLarge {
                await MainActor.run {
                    Log.d("NotificationAttachmentController", "Rejected \(logPrefix) attachment download for \(notificationID): too large")
                    if isAutomatic {
                        notification.skipAttachmentAutoDownload()
                    } else {
                        notification.failAttachmentDownload()
                    }
                    self.clearTransientProgressState(for: notification)
                }
            } catch {
                await MainActor.run {
                    Log.w("NotificationAttachmentController", "Failed \(logPrefix) attachment download for \(notificationID)", error)
                    notification.failAttachmentDownload()
                    self.clearTransientProgressState(for: notification)
                }
            }
        }
    }

    func cancelDownload(notification: Notification) {
        notification.cancelAttachmentDownload()
        clearTransientProgressState(for: notification)
        downloadTask?.cancel()
        downloadTask = nil
    }

    func deleteDownloadedFile(notification: Notification) {
        guard let localFileUrl = notification.attachmentLocalFileUrl() else {
            return
        }
        try? FileManager.default.removeItem(at: localFileUrl)
        notification.markAttachmentDeleted()
        clearTransientProgressState(for: notification)
    }

    deinit {
        downloadTask?.cancel()
    }

    private func setTransientProgressState(_ state: AttachmentProgressState, for notification: Notification) {
        activeNotificationObjectID = notification.objectID
        transientProgressState = state
    }

    private func clearTransientProgressState(for notification: Notification) {
        guard activeNotificationObjectID == notification.objectID else {
            return
        }
        activeNotificationObjectID = nil
        transientProgressState = nil
    }
}
