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
        }
        .padding(.all, 4)
    }
}
