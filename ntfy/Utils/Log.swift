import Foundation

struct Log {
    private static let dateFormat = "yyyy-MM-dd hh:mm:ss.SSSSSSZ"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = .current
        formatter.timeZone = .current
        return formatter
    }()
    
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
    
    private static func log(_ level: LogLevel, _ tag: String, _ message: String, _ other: Any?...) {
        print("\(dateStr()) ntfyApp [\(levelStr(level))] \(tag): \(message)")
        if !other.isEmpty {
            other.forEach { o in
                if let o = o {
                    print("  ", o)
                }
            }
        }
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
