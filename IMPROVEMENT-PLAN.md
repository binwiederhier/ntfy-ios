
# ntfy iOS App: Stabilization & Feature Parity Plan

**Warning:** AI-generated, but reviewed by Phil (binwiederhier)

## Current State

The ntfy iOS app is a ~2,500-line Swift/SwiftUI app that handles basic pub-sub notifications via Firebase Cloud Messaging. It works for simple use cases but is significantly behind the Android app in both reliability and features. Users are vocal about this — notification delivery issues alone have 86+ comments across multiple GitHub issues, and Discord shows a steady stream of iOS complaints over the past year.

A community member ([@dehlen](https://github.com/dehlen/ntfy-ios)) started a ground-up iOS rewrite in January 2026, which signals strong user demand. The rewrite was quickly abandoned, but may be salvagable. Multiple users on Discord have noted that "iOS is really behind."

### What works today
- Subscribe to topics on ntfy.sh and self-hosted servers (with upstream relay)
- Receive push notifications via FCM with title, message, priority, emoji tags
- View and HTTP notification actions
- Basic auth (username/password per server)
- Delete notifications, pull-to-refresh, dark mode

### What's missing or broken
See prioritized tiers below.

### Current architecture

iOS does not allow background processes, so WebSocket or JSON stream connections cannot be used. Apple requires that all push notifications go through the Apple Push Notification service (APNs). The notification flow depends on the server type:

- **ntfy.sh subscriptions:** Publisher → ntfy.sh → FCM → APNs → iOS device
- **Self-hosted servers:** Publisher → self-hosted ntfy → ntfy.sh (upstream relay) → FCM → APNs → iOS device → Notification Service Extension polls back to self-hosted server for actual message content

The self-hosted flow is awkward because it requires ntfy.sh involvement even for private servers, but this is unavoidable due to iOS platform constraints. The Notification Service Extension (NSE) runs in a separate process with a 25-second execution limit, handles incoming notifications, and shares data with the main app via Core Data through an App Group.

For a detailed explanation, see [the blog post on ntfy's iOS architecture](https://blog.ntfy.sh/2023/12/06/138-lines-of-code/#ios-app).

---

## Scope

- **iOS deployment target:** Bump from iOS 14 to **iOS 16+** (simplifies code significantly)
- **Critical Alerts entitlement:** Already obtained from Apple (priority 5 can use `.critical`)
- **Principle:** Reliability first, then most-requested features, then polish

---

## Priority 1: Stability Fixes — MUST DO

These are crashes and reliability issues that affect every user.

### 1A. Notifications silently break, requiring reinstall
**GitHub:** [#1305](https://github.com/binwiederhier/ntfy/issues/1305) (4 thumbs up, 16 comments), [#898](https://github.com/binwiederhier/ntfy/issues/898) (4 thumbs up, 25 comments), [#1003](https://github.com/binwiederhier/ntfy/issues/1003) (7 thumbs up, 16 comments)
**Discord:** 107 mentions of notification delivery problems in the last year

Push notifications stop arriving with no visible error. The only fix is reinstalling the app. Errors are logged but never shown to the user (acknowledged TODO in the codebase). This needs:
- Surface error states to the user (auth failures, network errors, Firebase registration issues)
- Investigate what app state corruption causes this and add recovery logic

### 1B. UI doesn't refresh after receiving notifications
**GitHub:** [#337](https://github.com/binwiederhier/ntfy/issues/337)

Users receive the iOS notification banner, but the in-app notification list doesn't update until they manually pull-to-refresh. The Notification Service Extension writes to Core Data, but the main app's UI doesn't reliably pick up those changes.

### 1C. App crashes when clearing notifications
**GitHub:** [#1642](https://github.com/binwiederhier/ntfy/issues/1642), [#377](https://github.com/binwiederhier/ntfy/issues/377)

Clearing all notifications or bulk-deleting crashes the app consistently. This is a Core Data threading bug — deletes are dispatched on a background thread but the Core Data context is main-queue.

### 1D. No sound on iOS 26 + breaks other app sounds
**GitHub:** [#1562](https://github.com/binwiederhier/ntfy/issues/1562)

On iOS 26.2+, ntfy notifications have no sound. Worse, receiving a silent ntfy notification breaks sound for *other* apps until the user makes a phone call. 100% reproducible. Possibly related to notification channel/category configuration.

---

## Priority 2: Most-Requested Features — SHOULD DO

These are the highest-voted feature requests on GitHub.

### 2A. Critical alerts & time-sensitive notifications
**GitHub:** [#1235](https://github.com/binwiederhier/ntfy/issues/1235) (31 thumbs up), [#332](https://github.com/binwiederhier/ntfy/issues/332) (7 thumbs up, 16 comments)

The #1 most upvoted iOS issue. Priority 4/5 notifications should bypass Focus mode and Do Not Disturb. The code sets the interruption levels but the required entitlements and capabilities aren't properly configured in the Xcode project. The Critical Alerts entitlement is available — it just needs to be wired up and tested end-to-end.

### 2B. Image & attachment display
**GitHub:** [#1226](https://github.com/binwiederhier/ntfy/issues/1226) (22 thumbs up), [#276](https://github.com/binwiederhier/ntfy/issues/276) (6 thumbs up)
**Discord:** 23 mentions in last year

The #2 most upvoted iOS issue. The server already sends attachment metadata via FCM (`attachment_url`, `attachment_name`, `attachment_type`, etc.) but the iOS app completely ignores these fields. Needs:
- Parse attachment fields from the push payload
- Download images in the Notification Service Extension and attach via `UNNotificationAttachment` (rich notification preview)
- Display images inline in the in-app notification list

### 2C. Clickable links in messages
**GitHub:** [#281](https://github.com/binwiederhier/ntfy/issues/281) (6 thumbs up), [#586](https://github.com/binwiederhier/ntfy/issues/586) (6 thumbs up), [#1480](https://github.com/binwiederhier/ntfy/issues/1480), [#1605](https://github.com/binwiederhier/ntfy/issues/1605)

Message text is rendered as plain, non-interactive text. URLs, phone numbers, and other links are not tappable. With the iOS 16+ deployment target, `Text(AttributedString(markdown:))` can handle this directly. This also partially addresses the Markdown rendering request ([#1072](https://github.com/binwiederhier/ntfy/issues/1072), 12 thumbs up).

### 2D. Copy-to-clipboard with feedback
**GitHub:** [#279](https://github.com/binwiederhier/ntfy/issues/279), [#1506](https://github.com/binwiederhier/ntfy/issues/1506)
**Discord:** 20 mentions in last year

There's a hidden tap-to-copy gesture with zero visual feedback. Users don't know it exists. Replace with a context menu (long-press) and add haptic/visual confirmation.

---

## Priority 3: Quality-of-Life — NICE TO HAVE

Completes the core feature set users expect.

### 2A. Display names for subscriptions
**GitHub:** [#1314](https://github.com/binwiederhier/ntfy/issues/1314) (7 thumbs up), [#357](https://github.com/binwiederhier/ntfy/issues/357) (3 thumbs up)

Users want to rename subscriptions to human-readable names instead of seeing raw topic URLs. Android has this.

### 2B. Per-subscription mute
**GitHub:** [#278](https://github.com/binwiederhier/ntfy/issues/278) (8 comments)

No way to mute a noisy topic without unsubscribing. Android has per-subscription mute with "mute until" options.

### 2C. Publish messages from the app
**GitHub:** [#301](https://github.com/binwiederhier/ntfy/issues/301) (3 thumbs up), [#302](https://github.com/binwiederhier/ntfy/issues/302)

The API call for publishing already exists in the codebase (used by "Send test notification"). Just needs a user-facing compose UI with message, title, priority, and tags fields.

### 2D. Show notification timestamps
**GitHub:** [#875](https://github.com/binwiederhier/ntfy/issues/875) (7 thumbs up)

Notification times should be visible in the message list.

### 2E. Unread/new message indicators
**GitHub:** [#280](https://github.com/binwiederhier/ntfy/issues/280) (4 thumbs up)

No visual distinction between read and unread notifications. Android shows green dots.

---

## Priority 4: Polish — IF TIME ALLOWS

### 3A. Auto-delete old notifications
**GitHub:** [#1549](https://github.com/binwiederhier/ntfy/issues/1549)

Add a setting to automatically clean up notifications older than N days.

### 3B. Swipe-back navigation
**GitHub:** [#312](https://github.com/binwiederhier/ntfy/issues/312)

The native iOS swipe-back gesture is disabled due to a custom back button. Should be restored.

### 3C. Markdown rendering
**GitHub:** [#1072](https://github.com/binwiederhier/ntfy/issues/1072) (12 thumbs up)

Partially addressed by 2C (clickable links). Full markdown would be a bonus if time allows.

---

## Out of Scope

| Item | Why |
|------|-----|
| Apple Watch support ([#1546](https://github.com/binwiederhier/ntfy/issues/1546)) | Entirely new watchOS app target, 20–40 hours alone |
| Custom notification sounds ([#546](https://github.com/binwiederhier/ntfy/issues/546), 9 thumbs up) | Medium effort, requires bundling sound files + mapping logic |
| ntfy:// deep links ([#450](https://github.com/binwiederhier/ntfy/issues/450), 10 thumbs up) | Requires server-side AASA file + URL scheme setup |
| Share extension | New app extension target, 8–15 hours |
| Self-signed certificate support ([#1439](https://github.com/binwiederhier/ntfy/issues/1439)) | Security-sensitive, niche use case |
| Notification icons ([#507](https://github.com/binwiederhier/ntfy/issues/507)) | iOS restricts notification icons to the app icon |
| MDM/config profiles ([#477](https://github.com/binwiederhier/ntfy/issues/477)) | Enterprise-only, specialized |
| Update/edit notifications | Server feature that was never wired into iOS; significant NSE work |

---

## Technical Notes

- **Deployment target is iOS 16+.** Remove all `if #available(iOS 15, *)` guards. Use modern APIs directly.
- **Core Data model changes need versioning.** Create a new model version in Xcode for lightweight migration.
- **The Notification Service Extension (NSE) runs in a separate process.** It shares Core Data via App Group `group.io.heckel.ntfy`. It has a 25-second execution limit.
- **Push notifications require a physical device.** NSE debugging requires Debug > Attach to Process.
- **Firebase config required.** You'll need the `GoogleService-Info.plist` or a test Firebase project.
- **Critical Alerts entitlement is available.** Make sure it's configured in Signing & Capabilities.
- **Commits should be per-feature** (not one giant commit). Update `docs/FEATURE_PARITY.md` as features are completed.

---

## Data Sources

- **GitHub issues:** [All open iOS issues sorted by thumbs up](https://github.com/binwiederhier/ntfy/issues?q=is%3Aissue+state%3Aopen+sort%3Areactions-%2B1-desc+label%3Aios)
- **Discord:** ntfy community server, ~440 iOS-related messages from March 2025–February 2026
- **Feature parity doc:** `ntfy-ios/docs/FEATURE_PARITY.md`
- **Technical limitations doc:** `ntfy-ios/docs/TECHNICAL_LIMITATIONS.md`
- **Community iOS rewrite:** [github.com/dehlen/ntfy-ios](https://github.com/dehlen/ntfy-ios) (started January 2026)
