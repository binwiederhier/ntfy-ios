import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// This file is compiled into the app, the notification service extension and the Live Activity widget extension,
// so it must not depend on anything else in the app (Store, Log, ...).

/// Icons downloaded by the app or the notification service extension are stored in the app group container,
/// so that the Live Activity widget (which cannot load remote images) can display them.
enum SharedIconFiles {
    static let appGroup = "group.io.heckel.ntfy" // Must match Store.appGroup

    static var directory: URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return nil
        }
        let directory = container.appendingPathComponent("Library/Caches/icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func fileUrl(name: String) -> URL? {
        directory?.appendingPathComponent(name)
    }
}

#if canImport(ActivityKit)
/// Attributes of the Live Activity driven by ntfy messages. Everything that can change lives in the
/// content state, since the attributes cannot be changed after the activity was started.
@available(iOS 16.1, *)
struct NtfyActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var status: String
        var progress: Double? // 0-100, nil hides the progress bar
        var iconFile: String? // File name in SharedIconFiles.directory
        var ended: Bool
        var updatedAt: Date
    }

    var key: String // "<topic>/<activity id>"
    var topic: String
}
#endif
