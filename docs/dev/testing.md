# Testing

## How we test

Tests follow a pyramid. Each layer up has fewer tests, but each one exercises more of the real system.

1. **Unit tests (wide).** Pure logic and Core Data, in process. Message parsing, notification content, Firebase topic
   names, and the `Store` against an in-memory database. Fast, and run in CI on every pull request.
2. **Integration tests (narrower).** A component talking to its real neighbor. For example, `ApiService` and the
   NSE against HTTP responses, first stubbed, then a real `ntfy serve`.
3. **End-to-end tests (fewest, deepest).** The app in the simulator. Pushes injected with `xcrun simctl push` and UI
   flows driven by XCUITest.

Start at the bottom. A bug fix gets a failing unit test first, then moves up a layer only when the bug lives
between components.

## Conventions

We use [Swift Testing](https://developer.apple.com/documentation/testing) and follow its documented idioms rather
than restating them here. Specific to this repo:

- Tests live in `ntfyTests/`, one file per type under test (`StoreTests.swift` for `Store`).
- Inputs that vary are parameterized with `@Test(arguments:)` instead of a test per case.
- Each test that touches Core Data creates its own `Store(inMemory: true)`. Tests that touch the store's main-queue
  context are `@MainActor`.
- No real network in unit tests. Use `example.com` hosts in fixtures.

## Running

Lint (SwiftLint plus plist, JSON, XML and shell checks):

```bash
scripts/lint.sh
```

Tests, the same way CI runs them. The Firebase placeholder is only needed if you don't have a real
`GoogleService-Info.plist`; ad-hoc signing avoids needing an Apple developer team on the simulator.

```bash
scripts/dummy-firebase-plist.sh
xcodebuild test \
  -project ntfy.xcodeproj \
  -scheme ntfy \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=
```

In Xcode, `Cmd+U` runs the same tests. CI (`.github/workflows/ci.yml`) runs lint, then tests, on every pull request and
push to `main`.

## Known gaps

- Unit tests cover helpers, message parsing, notification content and the `Store`. `ApiService`,
  `SubscriptionManager` and the NSE's `didReceive` have no tests.
- `ApiService` creates its own `URLSession`, so tests can't stub HTTP without a small change.
- There is no UI test target.
- CI doesn't collect code coverage.

## Next up

1. **Integration layer.** Let `ApiService` take a `URLSessionConfiguration`, then stub responses with a
   [`URLProtocol`](https://developer.apple.com/documentation/foundation/urlprotocol) subclass. Cover polling and the
   NSE's `poll_request` fetch.
2. **Real server.** Run `ntfy serve` on the CI runner and exercise publish, poll and auth end to end over HTTP.
3. **End-to-end layer.** Add a UI test target. Use `xcrun simctl push` to deliver sample payloads to the simulator
   and check what the app and NSE do with them.
4. **Coverage gate.** Once the layers above exist, run with `-enableCodeCoverage YES` and fail CI below a threshold.
