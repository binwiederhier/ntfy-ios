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
        if attachment.isDownloaded() {
            if let imageUrl = UIImage(contentsOfFile: attachment.contentUrl) {
                let image = Image(uiImage: imageUrl)
                    .resizable()
                    .scaledToFit()
                ZStack {
                    image
                }
                .onTapGesture {
                    isAttachmentOpen.toggle()
                }
                .fullScreenCover(isPresented: $isAttachmentOpen, onDismiss: {
                    // Dismiss logic here
                }, content: {
                    VStack {
                        image
                    }
                    .onTapGesture {
                        isAttachmentOpen.toggle()
                    }
                })
            }
        } else {
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
