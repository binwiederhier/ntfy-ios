import Foundation

struct NtfyDeepLink: Equatable, Identifiable {
    let baseUrl: String
    let topic: String
    let displayName: String?

    var id: String {
        "\(baseUrl)/\(topic)"
    }

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "ntfy",
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        let pathSegments = components.path
            .split(separator: "/", omittingEmptySubsequences: false)
            .dropFirst()
        guard pathSegments.count == 1,
              let topic = pathSegments.first,
              topic.range(of: "^[-_A-Za-z0-9]{1,64}$", options: .regularExpression) != nil else {
            return nil
        }

        let secureValue = components.queryItems?
            .first { $0.name == "secure" }?
            .value?
            .lowercased()
        let secure = secureValue != "false" && secureValue != "0"
        let defaultPort = secure ? 443 : 80

        var baseComponents = URLComponents()
        baseComponents.scheme = secure ? "https" : "http"
        baseComponents.host = host
        if components.port != defaultPort {
            baseComponents.port = components.port
        }

        guard let baseUrl = baseComponents.string else {
            return nil
        }

        let displayName = components.queryItems?
            .first { $0.name == "display" }?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        self.baseUrl = baseUrl
        self.topic = String(topic)
        self.displayName = displayName?.isEmpty == false ? displayName : nil
    }
}
