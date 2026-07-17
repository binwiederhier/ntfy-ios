# Per-topic emoji avatar

## Context

Topic rows in "Subscribed topics" show a colored circle with the topic's initial letter (`TopicAvatarView`), added as part of the UI modernization work in PR #49 / binwiederhier#49. The user wants to optionally replace that with a custom emoji per topic, picked by hand, so topics are more visually distinguishable at a glance than a single letter allows.

## Scope

- Applies to topic rows in `SubscriptionListView`'s "Subscribed topics" list only.
- Does **not** apply to the "All Notifications" pinned row (keeps its fixed `tray.full.fill` icon) or to the topic-name badges shown per-message inside the All Notifications feed (`NotificationRowView`'s `subscriptionLabel` capsule) — those are out of scope.
- No custom in-app searchable emoji grid. The app already bundles a full gemoji dataset (`EmojiManager`, `emojis.json`) used for parsing emoji tags in messages, but this feature relies on the native iOS emoji keyboard instead, to keep the picker UI minimal.

## Data model

Add an optional attribute to the `Subscription` entity in `ntfy.xcdatamodeld`:

```xml
<attribute name="icon" optional="YES" attributeType="String"/>
```

`nil`/empty means "no custom emoji — use the default colored initial-letter avatar." This is a lightweight Core Data migration (optional, no default value needed), consistent with how `isRead` was added to `Notification` previously. No new model version is required; `shouldMigrateStoreAutomatically`/`shouldInferMappingModelAutomatically` are already enabled on the store.

## Persistence

Add a `Store` method, following the existing pattern of other subscription/preference setters (e.g. `saveUser`, `saveDefaultBaseUrl`):

```swift
func saveIcon(for subscription: Subscription, icon: String?) {
    context.performAndWait {
        subscription.icon = (icon?.isEmpty ?? true) ? nil : icon
        try? context.save()
    }
}
```

## Row rendering

`TopicAvatarView` gains an optional `emoji: String?` parameter:
- When non-nil/non-empty: render just the emoji character, centered, no colored background (the emoji already carries its own color), same 40×40 footprint as today.
- When nil/empty: unchanged existing behavior — colored circle (hash-derived hue) with the topic's uppercased initial letter.

`SubscriptionItemRowView` passes `subscription.icon` into `TopicAvatarView`.

## Entry point

The avatar becomes its own tap target: wrap it in a `Button(action: { showEmojiEditor = true })` with `.buttonStyle(.plain)`, nested inside the row's content. Since the row itself sits inside `NavigationLink(value: NotificationsRoute.topic(subscription))` (in `SubscriptionItemNavView`), the inner `Button` intercepts its own tap and does not also trigger navigation — tapping anywhere else on the row still opens the topic as today.

## Emoji editor sheet

New view, e.g. `TopicIconEditorView`, presented via `.sheet(isPresented: $showEmojiEditor)` from `SubscriptionItemRowView` (or its parent nav view — whichever ends up holding the `@State` cleanly during implementation). Contents:

- A live preview of the avatar as currently configured (reuses `TopicAvatarView`).
- A single-character `TextField` bound to a local `@State` string. On any change, truncate to the **last** entered `Character` (Swift's `Character` is grapheme-cluster-aware, so multi-codepoint emoji — flags, ZWJ family sequences, skin-tone modifiers — stay intact as one unit) and immediately persist via `store.saveIcon(for:icon:)`. No separate "Save" step.
- A hint label: "Tap the field, then tap the globe/emoji key to pick one" (iOS has no dedicated "emoji-only" `UIKeyboardType`, so the user switches keyboards manually).
- A **Remove** button/action, shown only when an icon is currently set, that clears it (`store.saveIcon(for: subscription, icon: nil)`) and reverts the preview to the default letter avatar.
- A **Done** button to dismiss the sheet (matching the dismiss pattern already used by `SubscriptionAddView`/`UserEditorView`).

## Out of scope / non-goals

- No validation that the entered character is "actually an emoji" — if a user types a plain letter, it just renders as that letter with no background circle (harmless, not worth guarding against).
- No bulk/import/export of icons, no default emoji suggestions, no per-server or per-notification icons.

## Testing

- Manual: set an emoji on a topic, confirm the row shows it immediately (no colored background) and other rows are unaffected.
- Manual: set a multi-codepoint emoji (e.g. family or flag emoji) and confirm it isn't truncated to a broken partial glyph.
- Manual: remove an emoji and confirm the row reverts to the colored initial-letter avatar.
- Manual: confirm tapping the avatar opens the sheet without also navigating into the topic, and tapping elsewhere on the row still navigates normally.
- Build: `xcodebuild build` for the iOS Simulator after the model change, to confirm the lightweight migration compiles and the app launches against an existing store without a crash.
