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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shouldShowImagePreview {
                ZStack(alignment: .topTrailing) {
                    NotificationAttachmentImageView(
                        localFileUrl: notification.attachmentLocalFileUrl(),
                        isLoading: notification.isAttachmentDownloading()
                    )

                    if showsImageOnly, showsMenu {
                        previewMenuButton
                            .padding(8)
                    }
                }
            }

            if !showsImageOnly {
                HStack(alignment: .center, spacing: 10) {
                    Button(action: handlePrimaryTap) {
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

                    if notification.isAttachmentDownloading() {
                        ProgressView()
                            .scaleEffect(0.85)
                    }

                    if showsMenu {
                        previewMenuButton
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if notification.attachmentDownloadFailed() {
                Text("The last download attempt failed.")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.top, 8)
        .task(id: imageAutoDownloadKey) {
            autoDownloadInlineImageIfNeeded()
        }
    }

    @ViewBuilder
    private var attachmentMenuItems: some View {
        if let localFileUrl = notification.attachmentLocalFileUrl() {
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
        } else if notification.isAttachmentDownloading() {
            Button("Cancel") {
                controller.cancelDownload()
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

    private var shouldShowImagePreview: Bool {
        guard attachment.isImageAttachment() else {
            return false
        }
        return notification.attachmentLocalFileUrl() != nil || notification.isAttachmentDownloading()
    }

    private var statusText: String {
        notification.attachmentStatusDescription()
    }

    private var statusColor: Color {
        if notification.attachmentDownloadFailed() {
            return .red
        } else if attachmentExpired {
            return .red
        } else {
            return .gray
        }
    }

    private func handlePrimaryTap() {
        if let localFileUrl = notification.attachmentLocalFileUrl() {
            openLocalFile(localFileUrl)
        } else if !attachmentExpired && !notification.isAttachmentDownloading() {
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

    private var previewMenuButton: some View {
        Menu {
            attachmentMenuItems
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

    private var showsImageOnly: Bool {
        attachment.isImageAttachment() && notification.attachmentLocalFileUrl() != nil
    }

    private var showsMenu: Bool {
        if notification.attachmentLocalFileUrl() != nil {
            return true
        }
        if notification.isAttachmentDownloading() {
            return true
        }
        if !attachmentExpired {
            return true
        }
        return false
    }

    private var imageAutoDownloadKey: String {
        [
            notification.id ?? "",
            notification.attachmentLocalPath ?? "",
            String(notification.attachmentProgressValue())
        ].joined(separator: "|")
    }

    private func autoDownloadInlineImageIfNeeded() {
        guard attachment.isImageAttachment() else {
            return
        }
        guard notification.attachmentLocalFileUrl() == nil else {
            return
        }
        guard !notification.isAttachmentDownloading() else {
            return
        }
        guard !notification.attachmentDownloadFailed() else {
            return
        }
        guard !notification.attachmentWasDeleted() else {
            return
        }
        guard !attachmentExpired else {
            return
        }
        controller.startDownload(
            notification: notification,
            attachment: attachment,
            authorizationHeader: authorizationHeader
        )
    }
}
