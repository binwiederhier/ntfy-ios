//import CoreData
//import Foundation
//
//enum AttachmentDownloadResult {
//    case success(URL)
//    case skippedPolicy
//    case skippedTooLarge
//    case cancelled
//    case failed(Error)
//}
//
//private struct AttachmentDownloadSnapshot {
//    let notificationID: String
//    let attachment: MessageAttachment
//    let remoteURL: URL
//    let authorizationHeader: String?
//    let progress: Int16
//    let localFileURL: URL?
//}
//
//final class AttachmentDownloadManager {
//    static let shared = AttachmentDownloadManager()
//
//    private let queue = DispatchQueue(label: "io.heckel.ntfy.attachment-downloads")
//    private var tasks: [String: Task<AttachmentDownloadResult, Never>] = [:]
//
//    private init() {}
//
//    @MainActor
//    @discardableResult
//    func startManagedDownload(notification: Notification, userAction: Bool = true) -> Bool {
//        guard let notificationID = notification.id else {
//            return false
//        }
//        let objectID = notification.objectID
//
//        var didStart = false
//        queue.sync {
//            guard tasks[notificationID] == nil else {
//                return
//            }
//            let task = Task<AttachmentDownloadResult, Never> { [weak self] in
//                defer {
//                    self?.queue.sync {
//                        self?.tasks[notificationID] = nil
//                    }
//                }
//                return await self?.runDownload(notificationObjectID: objectID, userAction: userAction) ?? .failed(URLError(.unknown))
//            }
//            tasks[notificationID] = task
//            didStart = true
//        }
//        return didStart
//    }
//
//    func cancelManagedDownload(notificationID: String) {
//        let task: Task<AttachmentDownloadResult, Never>? = queue.sync {
//            let task = tasks[notificationID]
//            tasks[notificationID] = nil
//            return task
//        }
//        task?.cancel()
//    }
//
//    @MainActor
//    func autoDownloadIfNeeded(notification: Notification) async -> AttachmentDownloadResult {
//        let objectID = notification.objectID
//        guard let snapshot = snapshot(for: objectID) else {
//            return .failed(AttachmentDownloadError.missingUrl)
//        }
//        guard await shouldAutoDownload(snapshot: snapshot) else {
//            return .skippedPolicy
//        }
//        if let localFileURL = snapshot.localFileURL {
//            return .success(localFileURL)
//        }
//        return await runDownload(notificationObjectID: objectID, userAction: false)
//    }
//
//    private func shouldAutoDownload(snapshot: AttachmentDownloadSnapshot) async -> Bool {
//        if snapshot.attachment.isExpired() {
//            return false
//        }
//        if snapshot.localFileURL != nil || snapshot.progress == ATTACHMENT_PROGRESS_DELETED || snapshot.progress == ATTACHMENT_PROGRESS_DONE {
//            return false
//        }
//        if snapshot.progress == ATTACHMENT_PROGRESS_INDETERMINATE || (0..<ATTACHMENT_PROGRESS_DONE).contains(snapshot.progress) {
//            return false
//        }
//
//        let maxSize = await MainActor.run {
//            Store.shared.getAttachmentAutoDownloadMaxSize()
//        }
//        if maxSize == Store.autoDownloadNever {
//            return false
//        }
//        if maxSize == Store.autoDownloadAlways {
//            return true
//        }
//        guard let size = snapshot.attachment.size else {
//            return true
//        }
//        return size <= maxSize
//    }
//
//    private func runDownload(notificationObjectID: NSManagedObjectID, userAction: Bool) async -> AttachmentDownloadResult {
//        guard let snapshot = await snapshot(for: notificationObjectID) else {
//            return .failed(AttachmentDownloadError.missingUrl)
//        }
//        if let localFileURL = snapshot.localFileURL {
//            return .success(localFileURL)
//        }
//
//        let maxSize = await resolvedMaxSize(userAction: userAction)
//        if !userAction, let maxSize, let size = snapshot.attachment.size, size > maxSize {
//            return .skippedTooLarge
//        }
//
//        await updateNotification(notificationObjectID) { notification in
//            notification.beginAttachmentDownload()
//        }
//
//        do {
//            let downloaded = try await AttachmentFileStore.download(
//                notificationID: snapshot.notificationID,
//                remoteUrl: snapshot.remoteURL,
//                attachment: snapshot.attachment,
//                authorizationHeader: snapshot.authorizationHeader,
//                maxSize: maxSize,
//                onProgress: { progress in
//                    Task {
//                        await self.updateNotification(notificationObjectID) { notification in
//                            notification.setAttachmentDownloadProgress(progress)
//                        }
//                    }
//                }
//            )
//            await updateNotification(notificationObjectID) { notification in
//                notification.completeAttachmentDownload(
//                    localPath: downloaded.localFileUrl.path,
//                    resolvedType: downloaded.mimeType,
//                    resolvedSize: downloaded.size
//                )
//            }
//            return .success(downloaded.localFileUrl)
//        } catch is CancellationError {
//            await updateNotification(notificationObjectID) { notification in
//                notification.resetAttachmentDownload()
//            }
//            return .cancelled
//        } catch AttachmentDownloadError.tooLarge {
//            await updateNotification(notificationObjectID) { notification in
//                notification.resetAttachmentDownload()
//            }
//            return .skippedTooLarge
//        } catch {
//            await updateNotification(notificationObjectID) { notification in
//                notification.failAttachmentDownload()
//            }
//            return .failed(error)
//        }
//    }
//
//    @MainActor
//    private func snapshot(for notificationObjectID: NSManagedObjectID) -> AttachmentDownloadSnapshot? {
//        guard
//            let notification = try? Store.shared.context.existingObject(with: notificationObjectID) as? Notification,
//            let notificationID = notification.id,
//            let attachment = notification.messageAttachment(),
//            let remoteURL = notification.attachmentRemoteUrl(),
//            let baseUrl = notification.subscription?.baseUrl
//        else {
//            return nil
//        }
//        return AttachmentDownloadSnapshot(
//            notificationID: notificationID,
//            attachment: attachment,
//            remoteURL: remoteURL,
//            authorizationHeader: Store.shared.getUser(baseUrl: baseUrl)?.toBasicUser().toHeader(),
//            progress: notification.attachmentProgressValue(),
//            localFileURL: notification.attachmentLocalFileUrl()
//        )
//    }
//
//    @MainActor
//    private func updateNotification(_ notificationObjectID: NSManagedObjectID, update: @MainActor (Notification) -> Void) {
//        guard let notification = try? Store.shared.context.existingObject(with: notificationObjectID) as? Notification else {
//            return
//        }
//        update(notification)
//    }
//
//    private func resolvedMaxSize(userAction: Bool) async -> Int64? {
//        if userAction {
//            return nil
//        }
//
//        let maxSize = await MainActor.run {
//            Store.shared.getAttachmentAutoDownloadMaxSize()
//        }
//        if maxSize == Store.autoDownloadAlways {
//            return nil
//        }
//        if maxSize == Store.autoDownloadNever {
//            return 0
//        }
//        return maxSize
//    }
//}
