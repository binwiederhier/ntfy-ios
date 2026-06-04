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
    let onCopy: () -> Void
    @State private var isPreparingAutoDownload = false
    
    private var currentProgressState: AttachmentProgressState {
        controller.progressState(for: notification)
    }

    var body: some View {
        let resolvedLocalFileUrl = notification.attachmentLocalFileUrl()

        VStack(alignment: .leading, spacing: 8) {
            if shouldShowImagePreview(resolvedLocalFileUrl: resolvedLocalFileUrl) {
                ZStack(alignment: .topTrailing) {
                    NotificationAttachmentImageView(
                        localFileUrl: resolvedLocalFileUrl,
                        isLoading: notification.isAttachmentDownloading(overrideState: currentProgressState)
                    )

                    if showsImageOnly(resolvedLocalFileUrl: resolvedLocalFileUrl),
                       showsMenu(resolvedLocalFileUrl: resolvedLocalFileUrl) {
                        previewMenuButton(localFileUrl: resolvedLocalFileUrl)
                            .padding(8)
                    }
                }
            } else if shouldShowImagePlaceholder(resolvedLocalFileUrl: resolvedLocalFileUrl) {
                ZStack(alignment: .topTrailing) {
                    imagePlaceholderCard(localFileUrl: resolvedLocalFileUrl)

                    if showsMenu(resolvedLocalFileUrl: resolvedLocalFileUrl) {
                        previewMenuButton(localFileUrl: resolvedLocalFileUrl)
                            .padding(8)
                    }
                }
            }

            if !showsImageOnly(resolvedLocalFileUrl: resolvedLocalFileUrl)
                && !shouldShowImagePlaceholder(resolvedLocalFileUrl: resolvedLocalFileUrl) {
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
        .onAppear {
            syncPreparingAutoDownloadState(resolvedLocalFileUrl: resolvedLocalFileUrl)
        }
        .onChange(of: resolvedLocalFileUrl?.path ?? "") { _ in
            syncPreparingAutoDownloadState(resolvedLocalFileUrl: resolvedLocalFileUrl)
        }
        .onChange(of: currentProgressState.persistedValue) { _ in
            syncPreparingAutoDownloadState(resolvedLocalFileUrl: resolvedLocalFileUrl)
        }
        .task(id: attachmentAutoDownloadKey(resolvedLocalFileUrl: resolvedLocalFileUrl)) {
            autoDownloadAttachmentIfNeeded(resolvedLocalFileUrl: resolvedLocalFileUrl)
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
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onCopy()
            }
        }
    }

    private func imagePlaceholderCard(localFileUrl: URL?) -> some View {
        Button(action: {
            handlePrimaryTap(localFileUrl: localFileUrl)
        }) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemFill))
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .overlay {
                    VStack(spacing: 10) {
                        if shouldShowLoadingPlaceholder(resolvedLocalFileUrl: localFileUrl) {
                            ProgressView()
                        } else {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }

                        Text(attachment.displayName())
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        if !statusText.isEmpty {
                            Text(statusText)
                                .font(.caption)
                                .foregroundColor(statusColor)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        if !shouldShowLoadingPlaceholder(resolvedLocalFileUrl: localFileUrl) {
                            Text("Tap to load image")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.accentColor)
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(shouldShowLoadingPlaceholder(resolvedLocalFileUrl: localFileUrl))
    }

    private var attachmentExpired: Bool {
        notification.attachmentIsExpired()
    }

    private func shouldShowImagePreview(resolvedLocalFileUrl: URL?) -> Bool {
        guard attachment.isImageAttachment() else {
            return false
        }
        return resolvedLocalFileUrl != nil
    }

    private func shouldShowImagePlaceholder(resolvedLocalFileUrl: URL?) -> Bool {
        guard attachment.isImageAttachment() else {
            return false
        }
        guard resolvedLocalFileUrl == nil else {
            return false
        }
        return !attachmentExpired
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

    private func showsImageOnly(resolvedLocalFileUrl: URL?) -> Bool {
        attachment.isImageAttachment() && resolvedLocalFileUrl != nil
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

    private func attachmentAutoDownloadKey(resolvedLocalFileUrl: URL?) -> String {
        [
            notification.id ?? "",
            resolvedLocalFileUrl?.path ?? ""
        ].joined(separator: "|")
    }

    private func autoDownloadAttachmentIfNeeded(resolvedLocalFileUrl: URL?) {
        syncPreparingAutoDownloadState(resolvedLocalFileUrl: resolvedLocalFileUrl)
        guard shouldAutoDownloadAttachment(resolvedLocalFileUrl: resolvedLocalFileUrl) else {
            isPreparingAutoDownload = false
            if resolvedLocalFileUrl == nil,
               !attachmentExpired,
               currentProgressState == .none,
               !Store.shared.shouldAutoDownloadAttachment(attachment) {
                Log.d("NotificationAttachmentSectionView", "Skipping auto-download for \(notification.id ?? "<nil>") because it exceeds the auto-download policy")
                notification.skipAttachmentAutoDownload()
            }
            return
        }
        Log.d("NotificationAttachmentSectionView", "Starting auto-download for \(notification.id ?? "<nil>")")
        controller.startDownload(
            notification: notification,
            attachment: attachment,
            authorizationHeader: authorizationHeader,
            isAutomatic: true
        )
        isPreparingAutoDownload = false
    }

    private func shouldShowLoadingPlaceholder(resolvedLocalFileUrl: URL?) -> Bool {
        isPreparingAutoDownload || notification.isAttachmentDownloading(overrideState: currentProgressState)
    }

    private func shouldAutoDownloadAttachment(resolvedLocalFileUrl: URL?) -> Bool {
        guard resolvedLocalFileUrl == nil else {
            return false
        }
        guard !notification.isAttachmentDownloading(overrideState: currentProgressState) else {
            return false
        }
        guard currentProgressState != .failed else {
            return false
        }
        guard currentProgressState != .canceled else {
            return false
        }
        guard currentProgressState != .skipped else {
            return false
        }
        guard currentProgressState != .deleted else {
            return false
        }
        guard !attachmentExpired else {
            return false
        }
        guard Store.shared.shouldAutoDownloadAttachment(attachment) else {
            return false
        }
        return true
    }

    private func syncPreparingAutoDownloadState(resolvedLocalFileUrl: URL?) {
        isPreparingAutoDownload = attachment.isImageAttachment()
            && shouldAutoDownloadAttachment(resolvedLocalFileUrl: resolvedLocalFileUrl)
    }
}
