import Foundation
import UserNotifications

extension UNMutableNotificationContent {
    func modify(message: Message, baseUrl: String, notification: Notification? = nil) {
        // Body and title
        if let body = message.message {
            self.body = body
        }
        
        // Set notification title to short URL if there is no title. The title is always set
        // by the server, but it may be empty.
        if let title = message.title, title != "" {
            self.title = title
        } else {
            self.title = topicShortUrl(baseUrl: baseUrl, topic: message.topic)
        }
        
        // Emojify title or message
        let emojiTags = parseEmojiTags(message.tags)
        if !emojiTags.isEmpty {
            if let title = message.title, title != "" {
                self.title = emojiTags.joined(separator: "") + " " + self.title
            } else {
                self.body = emojiTags.joined(separator: "") + " " + self.body
            }
        }
        
        // Add custom actions
        //
        // We re-define the categories every time here, which is weird, but it works. When tapped, the action sets the
        // actionIdentifier in the application(didReceive) callback. This logic is handled in the AppDelegate. This approach
        // is described in a comment in https://stackoverflow.com/questions/30103867/changing-action-titles-in-interactive-notifications-at-run-time#comment122812568_30107065
        //
        // We also must set the .foreground flag, which brings the notification to the foreground and avoids an error about
        // permissions. This is described in https://stackoverflow.com/a/44580916/1440785
        appendAttachmentSummaryIfNeeded(message: message, notification: notification)
        configureNotificationActions(message: message)
        
        // Play a sound, and group by topic
        self.sound = .default
        self.threadIdentifier = topicUrl(baseUrl: baseUrl, topic: message.topic)
        
        // Map priorities to interruption level (light up screen, ...) and relevance (order)
        if #available(iOS 15.0, *) {
            switch message.priority {
            case 1:
                self.interruptionLevel = .passive
                self.relevanceScore = 0
            case 2:
                self.interruptionLevel = .passive
                self.relevanceScore = 0.25
            case 4:
                self.interruptionLevel = .timeSensitive
                self.relevanceScore = 0.75
            case 5:
                self.interruptionLevel = .critical
                self.relevanceScore = 1
            default:
                self.interruptionLevel = .active
                self.relevanceScore = 0.5
            }
        }
        
        // Make sure the userInfo matches, so that when the notification is tapped, the AppDelegate
        // can properly navigate to the right topic and re-assemble the message.
        self.userInfo = message.toUserInfo()
        self.userInfo["base_url"] = baseUrl
    }

    func attachImageIfNeeded(notification: Notification?, message: Message, user: BasicUser?, completionHandler: @escaping () -> Void) {
        guard
            let attachment = message.attachment,
            attachment.isImageAttachment(),
            let url = URL(string: attachment.url)
        else {
            completionHandler()
            return
        }

        if let localFileUrl = notification?.attachmentLocalFileUrl()
            ?? AttachmentFileStore.existingLocalFileUrl(
                notificationID: message.id,
                remoteUrl: url,
                attachment: attachment,
                mimeType: attachment.type
            ) {
            do {
                let notificationAttachment = try UNNotificationAttachment(identifier: "attachment", url: localFileUrl)
                self.attachments = self.attachments + [notificationAttachment]
            } catch {
                Log.w("NotificationContent", "Failed to attach local image", error)
            }
            completionHandler()
            return
        }

        var request = URLRequest(url: url)
        request.setValue(ApiService.userAgent, forHTTPHeaderField: "User-Agent")
        if let user = user {
            request.setValue(user.toHeader(), forHTTPHeaderField: "Authorization")
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 20

        URLSession(configuration: config).downloadTask(with: request) { tempUrl, response, _ in
            defer { completionHandler() }

            guard
                let tempUrl,
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                return
            }

            let mimeType = attachment.type ?? httpResponse.mimeType
            guard mimeType?.lowercased().hasPrefix("image/") == true || attachment.isImageAttachment() else {
                return
            }

            do {
                let downloaded = try AttachmentFileStore.storeDownloadedTemporaryFile(
                    notificationID: message.id,
                    remoteUrl: url,
                    attachment: attachment,
                    temporaryFileUrl: tempUrl,
                    mimeType: mimeType
                )
                Store.shared.completeAttachmentDownload(
                    notificationID: message.id,
                    localPath: downloaded.localFileUrl.path,
                    resolvedType: downloaded.mimeType,
                    resolvedSize: downloaded.size
                )
                let notificationAttachment = try UNNotificationAttachment(identifier: "attachment", url: downloaded.localFileUrl)
                self.attachments = self.attachments + [notificationAttachment]
            } catch {
                Log.w("NotificationContent", "Failed to create notification attachment", error)
            }
        }.resume()
    }

    private func configureNotificationActions(message: Message) {
        let userActions = message.actions ?? []
        let actions = userActions.prefix(4).map {
            UNNotificationAction(identifier: $0.id, title: $0.label, options: [.foreground])
        }

        guard !actions.isEmpty else {
            categoryIdentifier = ""
            return
        }

        let categoryIdentifier = "ntfyActions"
        self.categoryIdentifier = categoryIdentifier

        let center = UNUserNotificationCenter.current()
        let category = UNNotificationCategory(identifier: categoryIdentifier, actions: actions, intentIdentifiers: [])
        center.getNotificationCategories { existingCategories in
            let preservedCategories = existingCategories.filter { $0.identifier != categoryIdentifier }
            center.setNotificationCategories(Set(preservedCategories).union([category]))
        }
    }

    private func appendAttachmentSummaryIfNeeded(message: Message, notification: Notification?) {
        guard let attachment = message.attachment else {
            return
        }
        if attachment.isImageAttachment(), notification?.attachmentLocalFileUrl() != nil {
            return
        }

        let summary = notification?.notificationAttachmentSummary() ?? fallbackAttachmentSummary(attachment: attachment)
        guard !summary.isEmpty else {
            return
        }

        if body.isEmpty {
            body = summary
        } else {
            body = body + "\n\n" + summary
        }
    }
}

private func fallbackAttachmentSummary(attachment: MessageAttachment) -> String {
    var parts = [attachment.displayName()]
    if let size = attachment.size, size > 0 {
        parts.append(formatBytes(size))
    }
    if attachment.isExpired() {
        parts.append("expired")
    }
    return "Attachment: " + parts.joined(separator: ", ")
}
