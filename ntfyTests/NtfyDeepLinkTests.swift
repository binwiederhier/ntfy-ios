import XCTest

final class NtfyDeepLinkTests: XCTestCase {
    func testParsesAndroidCompatibleLink() {
        let link = parse("ntfy://example.com:8443/alerts?secure=true&display=Home%20Alerts")

        XCTAssertEqual(link?.baseUrl, "https://example.com:8443")
        XCTAssertEqual(link?.topic, "alerts")
        XCTAssertEqual(link?.displayName, "Home Alerts")
    }

    func testDefaultsToHTTPS() {
        XCTAssertEqual(parse("ntfy://example.com/alerts")?.baseUrl, "https://example.com")
    }

    func testSupportsInsecureLinks() {
        XCTAssertEqual(parse("ntfy://example.com/alerts?secure=false")?.baseUrl, "http://example.com")
        XCTAssertEqual(parse("ntfy://example.com/alerts?secure=0")?.baseUrl, "http://example.com")
    }

    func testNormalizesDefaultPorts() {
        XCTAssertEqual(parse("ntfy://example.com:443/alerts")?.baseUrl, "https://example.com")
        XCTAssertEqual(parse("ntfy://example.com:80/alerts?secure=false")?.baseUrl, "http://example.com")
    }

    func testPreservesNonDefaultPorts() {
        XCTAssertEqual(parse("ntfy://example.com:80/alerts")?.baseUrl, "https://example.com:80")
        XCTAssertEqual(parse("ntfy://example.com:443/alerts?secure=false")?.baseUrl, "http://example.com:443")
    }

    func testAcceptsValidTopicCharacters() {
        XCTAssertEqual(parse("ntfy://example.com/a-Z_09")?.topic, "a-Z_09")
        XCTAssertNotNil(parse("ntfy://example.com/\(String(repeating: "a", count: 64))"))
    }

    func testRejectsInvalidPathsAndTopics() {
        XCTAssertNil(parse("ntfy://example.com"))
        XCTAssertNil(parse("ntfy://example.com/"))
        XCTAssertNil(parse("ntfy://example.com/one/two"))
        XCTAssertNil(parse("ntfy://example.com/one/"))
        XCTAssertNil(parse("ntfy://example.com/invalid.topic"))
        XCTAssertNil(parse("ntfy://example.com/alerts%2Furgent"))
        XCTAssertNil(parse("ntfy://example.com/\(String(repeating: "a", count: 65))"))
    }

    func testRejectsWrongSchemeOrMissingHost() {
        XCTAssertNil(parse("https://example.com/alerts"))
        XCTAssertNil(parse("ntfy:///alerts"))
    }

    func testRejectsCredentialsAndFragments() {
        XCTAssertNil(parse("ntfy://user:password@example.com/alerts"))
        XCTAssertNil(parse("ntfy://example.com/alerts#section"))
    }

    func testTreatsBlankDisplayNameAsAbsent() {
        XCTAssertNil(parse("ntfy://example.com/alerts?display=%20%20")?.displayName)
    }

    func testQRCodeAcceptsNtfyAndWebTopicLinks() {
        XCTAssertEqual(parseQR("ntfy://example.com/alerts")?.baseUrl, "https://example.com")
        XCTAssertEqual(parseQR("https://example.com/alerts")?.baseUrl, "https://example.com")
        XCTAssertEqual(parseQR("http://example.com:8080/alerts")?.baseUrl, "http://example.com:8080")
    }

    func testQRCodeNormalizesWebDefaultPorts() {
        XCTAssertEqual(parseQR("https://example.com:443/alerts")?.baseUrl, "https://example.com")
        XCTAssertEqual(parseQR("http://example.com:80/alerts")?.baseUrl, "http://example.com")
    }

    func testQRCodeRejectsNonTopicURLsAndCredentials() {
        XCTAssertNil(parseQR("https://example.com/one/two"))
        XCTAssertNil(parseQR("https://user:password@example.com/alerts"))
        XCTAssertNil(parseQR("mailto:user@example.com"))
        XCTAssertNil(parseQR("not a URL"))
    }

    private func parse(_ value: String) -> NtfyDeepLink? {
        guard let url = URL(string: value) else {
            return nil
        }
        return NtfyDeepLink(url: url)
    }

    private func parseQR(_ value: String) -> NtfyDeepLink? {
        guard let url = URL(string: value) else {
            return nil
        }
        return NtfyDeepLink(qrCodeURL: url)
    }
}
