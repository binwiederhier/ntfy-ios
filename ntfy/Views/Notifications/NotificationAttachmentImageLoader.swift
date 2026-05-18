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
    @Published var isLoading = false

    private static let cache = NSCache<NSString, UIImage>()

    func load(from url: URL, authorizationHeader: String?) async {
        let cacheKey = cacheKey(for: url, authorizationHeader: authorizationHeader)
        if let cachedImage = Self.cache.object(forKey: cacheKey as NSString) {
            image = cachedImage
            didFail = false
            isLoading = false
            return
        }

        isLoading = true
        didFail = false
        image = nil

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
                isLoading = false
                didFail = true
                return
            }
            Self.cache.setObject(uiImage, forKey: cacheKey as NSString)
            image = uiImage
            didFail = false
            isLoading = false
        } catch {
            isLoading = false
            didFail = true
            Log.w("NotificationAttachmentImageLoader", "Failed to load attachment preview", error)
        }
    }

    private func cacheKey(for url: URL, authorizationHeader: String?) -> String {
        "\(url.absoluteString)|\(authorizationHeader ?? "")"
    }
}
