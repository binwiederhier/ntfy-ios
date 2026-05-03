import Foundation

/// Represents a parsed ntfy:// deep link URL.
///
/// Supports the following formats (matching the Android app):
///   - ntfy://host/topic
///   - ntfy://host/topic?display=Name
///   - ntfy://host/topic?secure=false
///   - ntfy://host:port/topic
///
/// When `secure` is false, the base URL uses http:// instead of https://.
struct NtfyDeepLink {
    let baseUrl: String
    let topic: String
    let displayName: String?

    /// Parse an ntfy:// URL into its components.
    ///
    /// Returns nil if the URL is malformed or missing required components (host, topic).
    /// The topic is extracted from the first path component and validated against the
    /// same regex used by the subscribe view: [-_A-Za-z0-9]{1,64}
    static func from(url: URL) -> NtfyDeepLink? {
        let tag = "NtfyDeepLink"

        guard url.scheme == "ntfy" else {
            Log.w(tag, "Ignoring URL with unexpected scheme: \(url.absoluteString)")
            return nil
        }

        guard let host = url.host, !host.isEmpty else {
            Log.w(tag, "Ignoring URL without host: \(url.absoluteString)")
            return nil
        }

        // Extract topic from path — the first non-empty path component
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let topic = pathComponents.first, !topic.isEmpty else {
            Log.w(tag, "Ignoring URL without topic: \(url.absoluteString)")
            return nil
        }

        // Validate topic format (same regex as SubscriptionAddView)
        guard topic.range(of: "^[-_A-Za-z0-9]{1,64}$", options: .regularExpression) != nil else {
            Log.w(tag, "Ignoring URL with invalid topic '\(topic)': \(url.absoluteString)")
            return nil
        }

        // Parse query parameters
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let secure = queryItems.first(where: { $0.name == "secure" })?.value != "false"
        let displayName = queryItems.first(where: { $0.name == "display" })?.value

        // Build base URL with scheme, host, and optional port
        let scheme = secure ? "https" : "http"
        let portSuffix = url.port.map { ":\($0)" } ?? ""
        let baseUrl = "\(scheme)://\(host)\(portSuffix)"

        return NtfyDeepLink(baseUrl: baseUrl, topic: topic, displayName: displayName)
    }
}
