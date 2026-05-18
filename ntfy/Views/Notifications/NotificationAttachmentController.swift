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
                    notification.completeAttachmentDownload(
                        localPath: downloaded.localFileUrl.path,
                        resolvedType: downloaded.mimeType,
                        resolvedSize: downloaded.size
                    )
                    self.clearTransientProgressState(for: notification)
                }
            } catch is CancellationError {
                await MainActor.run {
                    if !notification.attachmentDownloadWasCanceled() {
                        notification.resetAttachmentDownload()
                    }
                    self.clearTransientProgressState(for: notification)
                }
            } catch AttachmentDownloadError.tooLarge {
                await MainActor.run {
                    if isAutomatic {
                        notification.skipAttachmentAutoDownload()
                    } else {
                        notification.failAttachmentDownload()
                    }
                    self.clearTransientProgressState(for: notification)
                }
            } catch {
                await MainActor.run {
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
