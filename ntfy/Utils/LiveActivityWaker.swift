import Foundation

/// iOS doesn't let the notification service extension update Live Activities, but it does relaunch the containing app
/// in the background when a background URLSession download started by the extension finishes after the extension exited.
/// The extension uses that to wake the app, which then applies the queued Live Activity commands.
///
/// iOS does not relaunch an app the user force-quit from the app switcher, so this only helps while ntfy is in the background.
enum LiveActivityWaker {
    static let identifierPrefix = "io.heckel.ntfy.wake."
    private static let tag = "LiveActivityWaker"
    private static let delay: TimeInterval = 3 // The extension exits first (see NotificationService), otherwise the events go to it

    // One session per extension process: the system rejects a second session with the same identifier
    private static let handler = LiveActivityWakeHandler()
    private static let session = URLSession(
        configuration: configuration(identifier: identifierPrefix + UUID().uuidString),
        delegate: handler,
        delegateQueue: nil
    )

    static func configuration(identifier: String) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.background(withIdentifier: identifier)
        config.sharedContainerIdentifier = Store.appGroup
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return config
    }

    /// Called by the notification service extension after it queued a command it could not apply.
    static func scheduleWake(baseUrl: String) {
        guard let url = URL(string: normalizeBaseUrl(baseUrl) + "/v1/health") else {
            return
        }
        let task = session.downloadTask(with: url)
        task.earliestBeginDate = Date().addingTimeInterval(delay)
        task.resume()
        Log.d(tag, "Scheduled app wake-up via \(url)")
    }
}

/// Receives the background session events in the app after iOS relaunched it, see AppDelegate.
final class LiveActivityWakeHandler: NSObject, URLSessionDownloadDelegate {
    private var sessions: [String: URLSession] = [:]
    private var completionHandlers: [String: () -> Void] = [:]

    func handleEvents(identifier: String, completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.completionHandlers[identifier] = completionHandler
            self.sessions[identifier] = URLSession(
                configuration: LiveActivityWaker.configuration(identifier: identifier),
                delegate: self,
                delegateQueue: .main
            )
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The download itself is irrelevant, it only exists to wake the app
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            Log.w("LiveActivityWaker", "Wake-up download failed", error)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let identifier = session.configuration.identifier else {
            return
        }
        LiveActivityManager.processPending {
            DispatchQueue.main.async {
                self.sessions.removeValue(forKey: identifier)?.finishTasksAndInvalidate()
                self.completionHandlers.removeValue(forKey: identifier)?()
            }
        }
    }
}
