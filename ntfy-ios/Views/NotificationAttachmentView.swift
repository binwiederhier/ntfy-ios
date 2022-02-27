//
//  NotificationAttachmentView.swift
//  ntfy.sh
//
//  Created by Andrew Cope on 2/20/22.
//

import Foundation
import SwiftUI
import UIKit

struct NotificationAttachmentView: View {
    let attachment: NtfyAttachment

    @State private var isAttachmentOpen = false

    var body: some View {
        HStack {
            // TODO: Replace paperclip here with mimetype icon
            Image(systemName: "paperclip")
            VStack(alignment: .leading) {
                Text(attachment.name)
                    .font(.footnote)
                HStack {
                    Text(attachment.sizeString())
                        .font(.footnote)
                        .foregroundColor(.gray)
                    if (attachment.isDownloaded()) {
                        Text("Downloaded")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    } else {
                        Text("Not downloaded")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Text(attachment.expiresString())
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}
