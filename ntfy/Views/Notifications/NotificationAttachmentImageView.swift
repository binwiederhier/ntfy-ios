//
//  NotificationAttachmentImageView.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import SwiftUI

struct NotificationAttachmentImageView: View {
    @StateObject private var loader = NotificationAttachmentImageLoader()

    let imageUrl: URL
    let localFileUrl: URL?
    let authorizationHeader: String?

    var body: some View {
        Group {
            if let localFileUrl, let image = UIImage(contentsOfFile: localFileUrl.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if loader.didFail {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemFill))
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemFill))
                    .frame(height: 120)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: cacheKey) {
            guard localFileUrl == nil else {
                return
            }
            await loader.load(from: imageUrl, authorizationHeader: authorizationHeader)
        }
    }

    private var cacheKey: String {
        "\(imageUrl.absoluteString)|\(localFileUrl?.path ?? "")|\(authorizationHeader ?? "")"
    }
}

