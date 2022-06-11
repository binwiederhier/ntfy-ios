import Foundation

extension String {
    func toURL() -> URL {
        return URL(fileURLWithPath: self)
    }
}
