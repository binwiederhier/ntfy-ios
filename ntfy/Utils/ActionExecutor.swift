import Foundation
import UIKit
import UserNotifications

struct ActionExecutor {
    private static let tag = "ActionExecutor"

    /// Execute the given action. When `notificationId` is provided and the action's
    /// `clear` flag is true, the matching delivered notification is also removed from
    /// Notification Center so the user gets immediate visual confirmation that the
    /// tap registered. Documented at https://docs.ntfy.sh/publish/#action-buttons
    static func execute(_ action: Action, notificationId: String? = nil) {
        Log.d(tag, "Executing user action", action)
        switch action.action {
        case "view":
            if let url = URL(string: action.url ?? "") {
                open(url: url)
            } else {
                Log.w(tag, "Unable to parse action URL", action)
            }
        case "http":
            http(action)
        default:
            Log.w(tag, "Action \(action.action) not supported", action)
        }

        if action.clear == true, let id = notificationId {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        }
    }
    
    private static func http(_ action: Action) {
        guard let actionUrl = action.url, let url = URL(string: actionUrl) else {
            Log.w(tag, "Unable to execute HTTP action, no or invalid URL", action)
            return
        }
        let method = action.method ?? "POST" // POST is the default!!
        let body = action.body ?? ""

        Log.d(tag, "Performing HTTP \(method) \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        action.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if !["GET", "HEAD"].contains(method) {
            request.httpBody = body.data(using: .utf8)
        }
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                Log.e(self.tag, "Error performing HTTP \(method)", error!)
                return
            }
            Log.d(self.tag, "HTTP \(method) succeeded", response)
        }.resume()
    }
    
    private static func open(url: URL) {
        Log.d(tag, "Opening URL \(url)")
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
