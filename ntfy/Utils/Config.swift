import Foundation

enum Config {
    static var appBaseUrl: String {
        string(for: "AppBaseURL")
    }

    static private func string(for key: String) -> String {
        Bundle.main.infoDictionary?[key] as! String
    }
}
