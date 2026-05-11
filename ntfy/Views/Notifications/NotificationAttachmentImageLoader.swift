//
//  NotificationAttachmentImageLoader.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

// TODO: This will be converted to the @Observable macro at some point :)

import SwiftUI

@MainActor
final class NotificationAttachmentImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var didFail = false

    private static let cache = NSCache<NSURL, UIImage>()

    func load(from url: URL, authorizationHeader: String?) async {
        if let cachedImage = Self.cache.object(forKey: url as NSURL) {
            image = cachedImage
            didFail = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue(ApiService.userAgent, forHTTPHeaderField: "User-Agent")
        if let authorizationHeader = authorizationHeader {
            request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode),
                let uiImage = UIImage(data: data)
            else {
                didFail = true
                return
            }
            Self.cache.setObject(uiImage, forKey: url as NSURL)
            image = uiImage
            didFail = false
        } catch {
            didFail = true
            Log.w("NotificationAttachmentImageLoader", "Failed to load attachment preview", error)
        }
    }
}
