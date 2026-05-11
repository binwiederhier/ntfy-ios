//
//  NotificationAttachmentSectionView.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct NotificationAttachmentSectionView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var notification: Notification
    let attachment: MessageAttachment
    let authorizationHeader: String?
    @ObservedObject var controller: NotificationAttachmentController
    let onShare: (URL) -> Void
    let onSave: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shouldShowImagePreview, let imageUrl = notification.attachmentImageUrl() {
                NotificationAttachmentImageView(
                    imageUrl: imageUrl,
                    localFileUrl: notification.attachmentLocalFileUrl(),
                    authorizationHeader: authorizationHeader
                )
            }

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

                if controller.isDownloading {
                    ProgressView()
                        .scaleEffect(0.85)
                }

                Menu {
                    attachmentMenuItems
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(10)
            .background(Color(.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                handlePrimaryTap()
            }

            if let errorMessage = controller.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.top, 8)
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
        } else if controller.isDownloading {
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

        if let remoteUrl = notification.attachmentRemoteUrl() {
            Button("Copy URL") {
                UIPasteboard.general.setValue(remoteUrl.absoluteString, forPasteboardType: UTType.plainText.identifier)
            }
        }
    }

    private var attachmentExpired: Bool {
        guard let expires = attachment.expires else {
            return false
        }
        return expires < Int64(Date().timeIntervalSince1970)
    }

    private var shouldShowImagePreview: Bool {
        guard attachment.isImageAttachment() else {
            return false
        }
        return notification.attachmentLocalFileUrl() != nil || !attachmentExpired
    }

    private var statusText: String {
        var parts: [String] = []
        let detailText = notification.attachmentDetailText()
        if !detailText.isEmpty {
            parts.append(detailText)
        }
        if controller.isDownloading {
            parts.append("Downloading")
        } else if notification.attachmentLocalFileUrl() != nil {
            parts.append("Downloaded")
        } else if attachmentExpired {
            parts.append("Expired")
        }
        return parts.joined(separator: " · ")
    }

    private var statusColor: Color {
        if controller.errorMessage != nil {
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
        } else if !attachmentExpired && !controller.isDownloading {
            controller.startDownload(
                notification: notification,
                attachment: attachment,
                authorizationHeader: authorizationHeader
            )
        }
    }

    private func openLocalFile(_ localFileUrl: URL) {
        openURL(localFileUrl)
    }
}

