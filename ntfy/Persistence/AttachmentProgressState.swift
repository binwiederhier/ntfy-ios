//
//  AttachmentProgressState.swift
//  ntfy
//
//  Created by Alek Michelson on 5/17/26.
//

import Foundation

enum AttachmentProgressState: Equatable {
    case none
    case indeterminate
    case failed
    case deleted
    case canceled
    case skipped
    case progress(Int16)
    case done
    
    init(storedValue: Int16, hasAttachment: Bool, hasLocalFile: Bool) {
        if hasLocalFile {
            self = .done
            return
        }
        if storedValue == 0, hasAttachment {
            self = .none
            return
        }
        
        switch storedValue {
        case -1:
            self = .none
        case -2:
            self = .indeterminate
        case -3:
            self = .failed
        case -4:
            self = .deleted
        case -5:
            self = .canceled
        case -6:
            self = .skipped
        case 100...:
            self = .done
        case 0..<100:
            self = .progress(storedValue)
        default:
            self = .none
        }
    }
    
    var persistedValue: Int16 {
        switch self {
        case .none:
            return -1
        case .indeterminate:
            return -2
        case .failed:
            return -3
        case .deleted:
            return -4
        case .canceled:
            return -5
        case .skipped:
            return -6
        case .progress(let percent):
            return percent
        case .done:
            return 100
        }
    }
    
    var isDownloading: Bool {
        switch self {
        case .indeterminate, .progress:
            return true
        default:
            return false
        }
    }
}
