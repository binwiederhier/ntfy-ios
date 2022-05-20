//
//  Log.swift
//  ntfy
//
//  Created by Philipp Heckel on 5/18/22.
//

import Foundation

struct Log {
    static var dateFormat = "yyyy-MM-dd hh:mm:ss.SSSSSSZ"
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter
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
    
    static func log(_ level: LogLevel, _ tag: String, _ message: String, _ other: Any?...) {
        print("\(dateStr()) ntfyApp [\(levelStr(level))] \(tag): \(message)")
        if !other.isEmpty {
            other.forEach { o in
                if o != nil {
                    print("  ", o!)
                }
            }
        }
    }
    
    static func dateStr() -> String {
        return dateFormatter.string(from: Date())
    }
    
    static func levelStr(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING ⚠️"
        case .error: return "ERROR ‼️"
        }
    }
}

enum LogLevel {
    case debug
    case info
    case warning
    case error
}
