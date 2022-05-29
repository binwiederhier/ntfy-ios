import Foundation

enum Config {
    static var appBaseUrl: String {
        string(for: "AppBaseURL")
    }
    
    static var build: String {
        string(for: "CFBundleVersion")
    }
    
    static var version: String {
        string(for: "CFBundleShortVersionString")
    }
    
    static var osVersion: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return String(os.majorVersion) + "." + String(os.minorVersion) + "." + String(os.patchVersion)
    }
    
    static private func string(for key: String) -> String {
        Bundle.main.infoDictionary?[key] as! String
    }
}
