import Foundation
import UIKit
import Intents
import UserNotifications
import CryptoKit

/// Per-topic fallback icon URLs. They live in the shared app group defaults so that the notification
/// service extension can read them without touching Core Data.
enum TopicIconStore {
    private static let defaults = UserDefaults(suiteName: Store.appGroup)

    static func iconUrl(baseUrl: String, topic: String) -> String? {
        let value = defaults?.string(forKey: key(baseUrl: baseUrl, topic: topic))
        return (value?.isEmpty ?? true) ? nil : value
    }

    static func setIconUrl(_ iconUrl: String?, baseUrl: String, topic: String) {
        let trimmed = iconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            defaults?.removeObject(forKey: key(baseUrl: baseUrl, topic: topic))
        } else {
            defaults?.set(trimmed, forKey: key(baseUrl: baseUrl, topic: topic))
        }
    }

    private static func key(baseUrl: String, topic: String) -> String {
        "topicIcon." + topicUrl(baseUrl: baseUrl, topic: topic)
    }
}

/// Downloads icons, scales them down and caches them as PNG in the app group container.
/// Small files are required for notification avatars and Live Activities alike.
enum IconCache {
    private static let tag = "IconCache"
    private static let maxPixelSize: CGFloat = 256

    static func fileName(for iconUrl: String) -> String {
        let digest = SHA256.hash(data: Data(iconUrl.utf8))
        return String(digest.compactMap { String(format: "%02x", $0) }.joined().prefix(32)) + ".png"
    }

    /// Calls the completion handler with the local file URL of the icon, or nil if it cannot be loaded.
    static func load(iconUrl: String, baseUrl: String, user: BasicUser?, completionHandler: @escaping (URL?) -> Void) {
        guard let url = URL(string: iconUrl), url.scheme == "http" || url.scheme == "https" else {
            completionHandler(nil)
            return
        }
        guard let fileUrl = SharedIconFiles.fileUrl(name: fileName(for: iconUrl)) else {
            completionHandler(nil)
            return
        }
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            completionHandler(fileUrl)
            return
        }

        var request = URLRequest(url: url)
        request.setValue(ApiService.userAgent, forHTTPHeaderField: "User-Agent")
        if let user, iconUrl.hasPrefix(normalizeBaseUrl(baseUrl) + "/") {
            // Only send credentials to the server the message came from
            request.setValue(user.toHeader(), forHTTPHeaderField: "Authorization")
        }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10

        URLSession(configuration: config).dataTask(with: request) { data, response, error in
            guard
                let data,
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode),
                let image = UIImage(data: data),
                let png = scaled(image).pngData()
            else {
                Log.w(tag, "Cannot load icon \(iconUrl)", error)
                completionHandler(nil)
                return
            }
            do {
                try png.write(to: fileUrl, options: .atomic)
                completionHandler(fileUrl)
            } catch {
                Log.w(tag, "Cannot store icon \(iconUrl)", error)
                completionHandler(nil)
            }
        }.resume()
    }

    private static func scaled(_ image: UIImage) -> UIImage {
        let size = image.size
        let scale = min(1, maxPixelSize / max(size.width, size.height, 1))
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

extension UNMutableNotificationContent {
    /// Shows the message icon (X-Icon), or the icon configured for the topic, as the sender avatar of the notification.
    ///
    /// This uses iOS 15 communication notifications (INSendMessageIntent), which require the
    /// com.apple.developer.usernotifications.communication entitlement. If that fails, the icon is added as an
    /// image attachment instead (unless the message already has an image attachment).
    func applySenderIcon(message: Message, baseUrl: String, user: BasicUser?, completionHandler: @escaping (UNNotificationContent) -> Void) {
        let messageIcon = message.icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let iconUrl = messageIcon.isEmpty ? TopicIconStore.iconUrl(baseUrl: baseUrl, topic: message.topic) : messageIcon else {
            completionHandler(self)
            return
        }
        IconCache.load(iconUrl: iconUrl, baseUrl: baseUrl, user: user) { fileUrl in
            DispatchQueue.main.async {
                guard let fileUrl, let data = try? Data(contentsOf: fileUrl) else {
                    completionHandler(self)
                    return
                }
                if let updated = self.updatingWithSender(iconData: data) {
                    completionHandler(updated)
                    return
                }
                self.attachIcon(fileUrl: fileUrl)
                completionHandler(self)
            }
        }
    }

    private func updatingWithSender(iconData: Data) -> UNNotificationContent? {
        let conversationId = threadIdentifier.isEmpty ? title : threadIdentifier
        let image = INImage(imageData: iconData)
        let sender = INPerson(
            personHandle: INPersonHandle(value: conversationId, type: .unknown),
            nameComponents: nil,
            displayName: title,
            image: image,
            contactIdentifier: nil,
            customIdentifier: conversationId
        )
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: body,
            speakableGroupName: nil,
            conversationIdentifier: conversationId,
            serviceName: nil,
            sender: sender,
            attachments: nil
        )
        intent.setImage(image, forParameterNamed: \.sender)

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        interaction.donate { error in
            if let error {
                Log.w("NotificationIcon", "Cannot donate message interaction", error)
            }
        }
        do {
            return try updating(from: intent)
        } catch {
            Log.w("NotificationIcon", "Cannot turn notification into communication notification", error)
            return nil
        }
    }

    private func attachIcon(fileUrl: URL) {
        guard attachments.isEmpty else {
            return // Do not hide the message's own image
        }
        // UNNotificationAttachment moves the file, so hand it a copy of the cached icon
        let copyUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        do {
            try FileManager.default.copyItem(at: fileUrl, to: copyUrl)
            attachments = [try UNNotificationAttachment(identifier: "icon", url: copyUrl)]
        } catch {
            Log.w("NotificationIcon", "Cannot attach icon", error)
        }
    }
}
