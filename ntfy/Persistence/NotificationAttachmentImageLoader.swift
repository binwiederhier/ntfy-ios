//
//  NotificationAttachmentImageLoader.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import SwiftUI

@MainActor
final class NotificationAttachmentImageLoader: ObservableObject {
    enum Phase {
        case idle
        case loading
        case loaded
        case failed
    }

    @Published var image: UIImage?
    @Published private(set) var phase: Phase = .idle

    private static let cache = NSCache<NSString, UIImage>()
    private var currentPath: String?

    func load(from localFileUrl: URL?) async {
        guard let localFileUrl else {
            image = nil
            phase = .idle
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
            phase = .loaded
            return
        }

        phase = .loading
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
            phase = .loaded
        } else {
            image = nil
            phase = .failed
        }
    }
}
