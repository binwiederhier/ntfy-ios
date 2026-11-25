import Testing
@testable import ntfy

@MainActor
struct SubscriptionTests {
    let store = Store(inMemory: true)

    @Test(arguments: [
        (nil, "example.com/garage"),
        ("", "example.com/garage"),
        ("Garage door", "Garage door"),
    ] as [(String?, String)])
    func displayNameFallsBackToShortUrl(customDisplayName: String?, want: String) {
        let subscription = store.saveSubscription(baseUrl: "https://example.com", topic: "garage")
        subscription.customDisplayName = customDisplayName
        #expect(subscription.displayName() == want)
    }
}
