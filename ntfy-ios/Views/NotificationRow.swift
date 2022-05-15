//
//  NotificationRow.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 1/15/22.
//

import SwiftUI

struct NotificationRow: View {
    let notification: NtfyNotification

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(notification.displayTitle())
                    .font(.headline)
                    .bold()
                    .lineLimit(1)
                Spacer()
                if notification.hasEmojiTags() {
                    Text(notification.displayEmojiTags())
                }
                Text(notification.displayShortDateTime())
                    .font(.subheadline)
                    .foregroundColor(.gray)
                if notification.priority == 4 {
                    Image(systemName: "exclamationmark")
                        .foregroundColor(.red)
                }
                if notification.priority == 5 {
                    Image(systemName: "exclamationmark.3")
                        .foregroundColor(.red)
                }
            }
            Spacer()
            Text(notification.message)
                .font(.body)
            if notification.hasNonEmojiTags() {
                Spacer()
                Text("Tags: " + notification.displayNonEmojiTags())
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            if let attachment = notification.attachment {
                Spacer()
                NotificationAttachmentView(attachment: attachment)
            }
        }
        .padding(.all, 4)
        .onTapGesture {
            if let attachment = notification.attachment {
                if !attachment.isDownloaded() && !attachment.isExpired() {
                    attachment.download()
                }
            }
        }
    }
}
