//
//  NotificationAttachmentImageLoader.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import SwiftUI

@MainActor
final class NotificationAttachmentImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false

    private static let cache = NSCache<NSString, UIImage>()
    private var currentPath: String?

    func load(from localFileUrl: URL?) async {
        guard let localFileUrl else {
            image = nil
            isLoading = false
            currentPath = nil
            return
        }

        let path = localFileUrl.path
        guard currentPath != path || image == nil else {
            return
        }

        currentPath = path
        if let cachedImage = Self.cache.object(forKey: path as NSString) {
            image = cachedImage
            isLoading = false
            return
        }

        isLoading = true
        image = nil

        let decodedImage = await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: path)
        }.value

        guard currentPath == path else {
            return
        }

        if let decodedImage {
            Self.cache.setObject(decodedImage, forKey: path as NSString)
            image = decodedImage
        } else {
            image = nil
        }
        isLoading = false
    }
}
