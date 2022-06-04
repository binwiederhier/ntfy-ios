import Foundation

extension User {
    func toBasicUser() -> BasicUser {
        return BasicUser(username: username ?? "?", password: password ?? "?")
    }
}
