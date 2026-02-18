import Foundation

struct Log {
    private static let dateFormat = "yy-MM-dd hh:mm:ss.SSS"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = .current
        formatter.timeZone = .current
        return formatter
    }()

    // Persistent log file in the shared App Group container so both the main app
    // and the Notification Service Extension write to the same file. The file is
    // capped at ~512 KB; when exceeded the oldest half is discarded so recent
    // entries (NSE triggers, APNs/FCM token events) are always preserved.
    private static let appGroup = "group.io.heckel.ntfy"
    private static let maxLogFileSize = 512 * 1024  // 512 KB
    private static let fileQueue = DispatchQueue(label: "io.heckel.ntfy.log", qos: .background)

    static var logFileUrl: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("ntfy.log")
    }

    static func d(_ tag: String, _ message: String, _ other: Any?...) {
        log(.debug, tag, message, other)
    }

    static func i(_ tag: String, _ message: String, _ other: Any?...) {
        log(.info, tag, message, other)
    }

    static func w(_ tag: String, _ message: String, _ other: Any?...) {
        log(.warning, tag, message, other)
    }

    static func e(_ tag: String, _ message: String, _ other: Any?...) {
        log(.error, tag, message, other)
    }

    /// Returns the full contents of the persisted log file, or an empty string if unavailable.
    static func readAll() -> String {
        guard let url = logFileUrl,
              let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return ""
        }
        return content
    }

    private static func log(_ level: LogLevel, _ tag: String, _ message: String, _ other: Any?...) {
        let line = "\(dateStr()) ntfyApp [\(levelStr(level))] \(tag): \(message)"
        print(line)
        var extra = ""
        if !other.isEmpty {
            other.forEach { o in
                if let o = o {
                    print("  ", o)
                    extra += "\n  \(o)"
                }
            }
        }
        appendToFile(line + extra)
    }

    private static func appendToFile(_ line: String) {
        guard let url = logFileUrl else { return }
        fileQueue.async {
            let entry = line + "\n"
            guard let data = entry.data(using: .utf8) else { return }
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                defer { fileHandle.closeFile() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                rotateIfNeeded(url: url)
            } else {
                // First write: create the file
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    // Keeps the newest half of the file when the size limit is reached, so
    // the log never grows unbounded while always retaining the most recent entries.
    private static func rotateIfNeeded(url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int, size > maxLogFileSize,
              let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n")
        let trimmed = lines.dropFirst(lines.count / 2).joined(separator: "\n")
        try? trimmed.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func dateStr() -> String {
        dateFormatter.string(from: Date())
    }

    private static func levelStr(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING ⚠️"
        case .error: return "ERROR ‼️"
        }
    }
}

private enum LogLevel {
    case debug
    case info
    case warning
    case error
}
