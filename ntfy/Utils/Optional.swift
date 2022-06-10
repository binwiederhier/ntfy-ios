import Foundation

/// This extension allows us to call .orThrow() on optional types to convert them to a throwable.
/// Heavily inspired by https://forums.swift.org/t/throw-on-nil/39970/7
extension Optional {
    func orThrow(_ error: @autoclosure () -> Error) throws -> Wrapped {
        if let wrapped = self { return wrapped }
        throw error()
    }
    
    func orThrow() throws -> Wrapped {
        if let wrapped = self { return wrapped }
        throw NilError(msg: "Variable is nil, but should not be")
    }
    
    func orThrow(_ msg: String) throws -> Wrapped {
        if let wrapped = self { return wrapped }
        throw NilError(msg: msg)
    }
    
    func or(_ w: Wrapped) -> Wrapped {
        if let wrapped = self { return wrapped }
        return w
    }
    
    struct NilError: Error {
        var msg: String
    }
}
