//
//  NotificationRowView.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct NotificationRowView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.openURL) private var openURL
    @ObservedObject var notification: Notification
    let onCopyMessage: () -> Void
    @StateObject private var attachmentController = NotificationAttachmentController()
    @State private var attachmentPresentation: AttachmentPresentation?
    
    var body: some View {
        notificationRow
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    store.delete(notification: notification)
                } label: {
                    Label("Delete", systemImage: "trash.circle")
                }
            }
            .sheet(item: $attachmentPresentation) { attachmentPresentation in
                switch attachmentPresentation.mode {
                case .share:
                    ActivityView(activityItems: [attachmentPresentation.url])
                case .save:
                    AttachmentExportView(url: attachmentPresentation.url)
                }
            }
    }
    
    private var notificationRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                HStack(alignment: .center, spacing: 2) {
                    Text(notification.shortDateTime())
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    if [1,2,4,5].contains(notification.priority) {
                        Image("priority-\(notification.priority)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }
                }
                Spacer()
                if clickUrl != nil {
                    messageActionsMenu
                }
            }
            .padding([.bottom], 2)
            if let title = notification.formatTitle(), title != "" {
                Text(title)
                    .font(.headline)
                    .bold()
                    .padding([.bottom], 2)
            }
            messageText
            if let attachment = notification.messageAttachment() {
                NotificationAttachmentSectionView(
                    notification: notification,
                    attachment: attachment,
                    authorizationHeader: attachmentAuthorizationHeader,
                    controller: attachmentController,
                    onShare: { attachmentPresentation = AttachmentPresentation(url: $0, mode: .share) },
                    onSave: { attachmentPresentation = AttachmentPresentation(url: $0, mode: .save) }
                )
            }
            if !notification.nonEmojiTags().isEmpty {
                Text("Tags: " + notification.nonEmojiTags().joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding([.top], 2)
            }
            if !notification.actionsList().isEmpty {
                HStack {
                    ForEach(notification.actionsList()) { action in
                        Button(action.label) {
                            ActionExecutor.execute(action)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding([.top], 5)
            }
        }
        .padding(.all, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            handleRowTap()
        }
    }
    
    private var messageText: some View {
        Group {
            Text(notification.linkifiedMessageAttributedString())
                .font(.body)
        }
    }
    
    private var clickUrl: URL? {
        guard let click = notification.click, !click.isEmpty else {
            return nil
        }
        return URL(string: click)
    }

    private var attachmentAuthorizationHeader: String? {
        guard
            let baseUrl = notification.subscription?.baseUrl,
            let user = store.getUser(baseUrl: baseUrl)?.toBasicUser()
        else {
            return nil
        }
        return user.toHeader()
    }
    
    private var messageActionsMenu: some View {
        Menu {
            Button("Copy message") {
                copyMessage()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        }
        .menuStyle(.borderlessButton)
    }
    
    private func copyMessage() {
        UIPasteboard.general.setValue(notification.formatMessage(), forPasteboardType: UTType.plainText.identifier)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onCopyMessage()
    }
    
    private func handleRowTap() {
        if let clickUrl {
            openURL(clickUrl)
        } else {
            copyMessage()
        }
    }
}

// MARK: Helper structs
extension NotificationRowView {
    private struct ActivityView: UIViewControllerRepresentable {
        let activityItems: [Any]

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        }
    }

    private struct AttachmentPresentation: Identifiable {
        enum Mode {
            case share, save
        }

        let id = UUID()
        let url: URL
        let mode: Mode
    }

    private struct AttachmentExportView: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        }

        func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        }
    }

}

