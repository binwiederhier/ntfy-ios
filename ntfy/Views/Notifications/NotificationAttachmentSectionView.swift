//
//  NotificationAttachmentSectionView.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct NotificationAttachmentSectionView: View {
    @ObservedObject var notification: Notification
    let attachment: MessageAttachment
    let authorizationHeader: String?
    @ObservedObject var controller: NotificationAttachmentController
    let onOpen: (URL) -> Void
    let onShare: (URL) -> Void
    let onSave: (URL) -> Void
    
    private var currentProgressState: AttachmentProgressState {
        controller.progressState(for: notification)
    }

    var body: some View {
        let storedLocalFileUrl = notification.attachmentStoredLocalFileUrl()
        let resolvedLocalFileUrl = notification.attachmentLocalFileUrl()

        VStack(alignment: .leading, spacing: 8) {
            if shouldShowImagePreview(storedLocalFileUrl: storedLocalFileUrl) {
                ZStack(alignment: .topTrailing) {
                    NotificationAttachmentImageView(
                        localFileUrl: storedLocalFileUrl,
                        isLoading: notification.isAttachmentDownloading(overrideState: currentProgressState)
                    )

                    if showsImageOnly(storedLocalFileUrl: storedLocalFileUrl),
                       showsMenu(resolvedLocalFileUrl: resolvedLocalFileUrl) {
                        previewMenuButton(localFileUrl: resolvedLocalFileUrl)
                            .padding(8)
                    }
                }
            }

            if !showsImageOnly(storedLocalFileUrl: storedLocalFileUrl) {
                HStack(alignment: .center, spacing: 10) {
                    Button(action: {
                        handlePrimaryTap(localFileUrl: resolvedLocalFileUrl)
                    }) {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: attachment.systemImageName())
                                .font(.title3)
                                .foregroundColor(.gray)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(attachment.displayName())
                                    .font(.subheadline)
                                    .bold()
                                    .lineLimit(2)
                                if !statusText.isEmpty {
                                    Text(statusText)
                                        .font(.caption)
                                        .foregroundColor(statusColor)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if notification.isAttachmentDownloading(overrideState: currentProgressState) {
                        ProgressView()
                            .scaleEffect(0.85)
                    }

                    if showsMenu(resolvedLocalFileUrl: resolvedLocalFileUrl) {
                        previewMenuButton(localFileUrl: resolvedLocalFileUrl)
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if currentProgressState == .failed {
                Text("The last download attempt failed.")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.top, 8)
        .task(id: imageAutoDownloadKey(storedLocalFileUrl: storedLocalFileUrl)) {
            autoDownloadInlineImageIfNeeded(storedLocalFileUrl: storedLocalFileUrl)
        }
    }

    @ViewBuilder
    private func attachmentMenuItems(localFileUrl: URL?) -> some View {
        if let localFileUrl {
            Button("Open") {
                openLocalFile(localFileUrl)
            }
            Button("Share") {
                onShare(localFileUrl)
            }
            Button("Save") {
                onSave(localFileUrl)
            }
            Button("Delete download", role: .destructive) {
                controller.deleteDownloadedFile(notification: notification)
            }
        } else if notification.isAttachmentDownloading(overrideState: currentProgressState) {
            Button("Cancel") {
                controller.cancelDownload(notification: notification)
            }
        } else if !attachmentExpired {
            Button("Download") {
                controller.startDownload(
                    notification: notification,
                    attachment: attachment,
                    authorizationHeader: authorizationHeader
                )
            }
        }

        if !attachmentExpired, let remoteUrl = notification.attachmentRemoteUrl() {
            Button("Copy URL") {
                UIPasteboard.general.setValue(remoteUrl.absoluteString, forPasteboardType: UTType.plainText.identifier)
            }
        }
    }

    private var attachmentExpired: Bool {
        notification.attachmentIsExpired()
    }

    private func shouldShowImagePreview(storedLocalFileUrl: URL?) -> Bool {
        guard attachment.isImageAttachment() else {
            return false
        }
        return storedLocalFileUrl != nil || notification.isAttachmentDownloading(overrideState: currentProgressState)
    }

    private var statusText: String {
        notification.attachmentStatusDescription(overrideState: currentProgressState)
    }

    private var statusColor: Color {
        if currentProgressState == .failed {
            return .red
        } else if attachmentExpired {
            return .red
        } else {
            return .gray
        }
    }

    private func handlePrimaryTap(localFileUrl: URL?) {
        if let localFileUrl {
            openLocalFile(localFileUrl)
        } else if !attachmentExpired && !notification.isAttachmentDownloading(overrideState: currentProgressState) {
            controller.startDownload(
                notification: notification,
                attachment: attachment,
                authorizationHeader: authorizationHeader
            )
        }
    }

    private func openLocalFile(_ localFileUrl: URL) {
        onOpen(localFileUrl)
    }

    private func previewMenuButton(localFileUrl: URL?) -> some View {
        Menu {
            attachmentMenuItems(localFileUrl: localFileUrl)
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Circle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func showsImageOnly(storedLocalFileUrl: URL?) -> Bool {
        attachment.isImageAttachment() && storedLocalFileUrl != nil
    }

    private func showsMenu(resolvedLocalFileUrl: URL?) -> Bool {
        if resolvedLocalFileUrl != nil {
            return true
        }
        if notification.isAttachmentDownloading(overrideState: currentProgressState) {
            return true
        }
        if !attachmentExpired {
            return true
        }
        return false
    }

    private func imageAutoDownloadKey(storedLocalFileUrl: URL?) -> String {
        [
            notification.id ?? "",
            storedLocalFileUrl?.path ?? "",
            String(currentProgressState.persistedValue)
        ].joined(separator: "|")
    }

    private func autoDownloadInlineImageIfNeeded(storedLocalFileUrl: URL?) {
        guard attachment.isImageAttachment() else {
            return
        }
        guard storedLocalFileUrl == nil else {
            return
        }
        guard !notification.isAttachmentDownloading(overrideState: currentProgressState) else {
            return
        }
        guard currentProgressState != .failed else {
            return
        }
        guard currentProgressState != .canceled else {
            return
        }
        guard currentProgressState != .skipped else {
            return
        }
        guard currentProgressState != .deleted else {
            return
        }
        guard !attachmentExpired else {
            return
        }
        guard Store.shared.shouldAutoDownloadAttachment(attachment) else {
            notification.skipAttachmentAutoDownload()
            return
        }
        controller.startDownload(
            notification: notification,
            attachment: attachment,
            authorizationHeader: authorizationHeader,
            isAutomatic: true
        )
    }
}
