# Per-topic Emoji Avatar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user set a custom emoji per subscribed topic, shown instead of the default colored initial-letter avatar on that topic's row in "Subscribed topics".

**Architecture:** One new optional Core Data attribute (`Subscription.icon`), one new `Store` persistence method, an extension to the existing `TopicAvatarView` to render an emoji when present, and a new small sheet view (`TopicIconEditorView`) opened by tapping the avatar, which edits that attribute directly.

**Tech Stack:** SwiftUI, Core Data (lightweight migration), no new dependencies.

## Global Constraints

- Applies only to topic rows in `SubscriptionListView`'s "Subscribed topics" list. Do not touch the "All Notifications" pinned row's icon or the topic-name badges inside the All Notifications feed.
- No custom searchable emoji picker — rely on the native iOS emoji keyboard (user taps the field, then the globe/emoji key).
- `nil`/empty `icon` means "no custom emoji" and must fall back to the existing colored initial-letter avatar exactly as it renders today.
- This project has no XCTest target (`xcodebuild -list` shows only the `ntfy` and `ntfyNSE` schemes, no test target) — every task's verification step is a build check plus a concrete manual check, not an automated test.
- Deployment target is iOS 16 (already set project-wide); avoid APIs newer than that unless already guarded elsewhere in the codebase the way `ContentUnavailableView` is (`#available(iOS 17.0, *)`).
- Match existing code conventions exactly: `Store` mutation methods use `context.performAndWait { ...; try? context.save() }` (see `Store.swift:144` `delete(subscription:)` for the pattern); dismiss-style sheets use a "Done" button matching `SubscriptionAddView`/`UserEditorView`.

---

### Task 1: Add `icon` attribute to the Core Data model

**Files:**
- Modify: `ntfy/Persistence/ntfy.xcdatamodeld/Model.xcdatamodel/contents`

**Interfaces:**
- Produces: `Subscription.icon: String?` (Core Data codegen will synthesize this on the `Subscription` managed object class, matching how `Notification.isRead` was synthesized previously).

- [ ] **Step 1: Add the attribute**

In `ntfy/Persistence/ntfy.xcdatamodeld/Model.xcdatamodel/contents`, find the `Subscription` entity (currently lines 31-42):

```xml
    <entity name="Subscription" representedClassName="Subscription" syncable="YES" codeGenerationType="class">
        <attribute name="baseUrl" attributeType="String"/>
        <attribute name="lastNotificationId" optional="YES" attributeType="String"/>
        <attribute name="topic" attributeType="String" minValueString="1" maxValueString="64" regularExpressionString="^[-_A-Za-z0-9]{1,64}$"/>
        <relationship name="notifications" optional="YES" toMany="YES" deletionRule="Cascade" destinationEntity="Notification" inverseName="subscription" inverseEntity="Notification"/>
```

Change it to:

```xml
    <entity name="Subscription" representedClassName="Subscription" syncable="YES" codeGenerationType="class">
        <attribute name="baseUrl" attributeType="String"/>
        <attribute name="icon" optional="YES" attributeType="String"/>
        <attribute name="lastNotificationId" optional="YES" attributeType="String"/>
        <attribute name="topic" attributeType="String" minValueString="1" maxValueString="64" regularExpressionString="^[-_A-Za-z0-9]{1,64}$"/>
        <relationship name="notifications" optional="YES" toMany="YES" deletionRule="Cascade" destinationEntity="Notification" inverseName="subscription" inverseEntity="Notification"/>
```

(Only the new `icon` line is added, alphabetically between `baseUrl` and `lastNotificationId`.)

- [ ] **Step 2: Build to verify the migration compiles**

Run: `cd /Users/hibikipr/Developer/ntfy-ios && xcodebuild build -scheme ntfy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

Expected: exits with no output and status 0 (`echo $?` prints `0`). This confirms Core Data code generation picked up the new attribute and the app still compiles — no new model version file is needed since this is a lightweight migration (optional attribute, no default value required) and the store already has `shouldMigrateStoreAutomatically`/`shouldInferMappingModelAutomatically` enabled (`Store.swift:51-52`).

- [ ] **Step 3: Commit**

```bash
cd /Users/hibikipr/Developer/ntfy-ios
git add ntfy/Persistence/ntfy.xcdatamodeld/Model.xcdatamodel/contents
git commit -m "Add icon attribute to Subscription for per-topic emoji avatars"
```

---

### Task 2: Add `Store.saveIcon(for:icon:)`

**Files:**
- Modify: `ntfy/Persistence/Store.swift`

**Interfaces:**
- Consumes: `Subscription.icon: String?` (Task 1).
- Produces: `Store.saveIcon(for subscription: Subscription, icon: String?)` — later tasks call this exact signature.

- [ ] **Step 1: Add the method**

In `ntfy/Persistence/Store.swift`, find `getSubscriptions()` (currently lines 120-122):

```swift
    func getSubscriptions() -> [Subscription]? {
        return try? context.fetch(Subscription.fetchRequest())
    }
```

Add a new method directly after it:

```swift
    func getSubscriptions() -> [Subscription]? {
        return try? context.fetch(Subscription.fetchRequest())
    }

    func saveIcon(for subscription: Subscription, icon: String?) {
        context.performAndWait {
            subscription.icon = (icon?.isEmpty ?? true) ? nil : icon
            try? context.save()
        }
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd /Users/hibikipr/Developer/ntfy-ios && xcodebuild build -scheme ntfy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

Expected: exit status 0, no output.

- [ ] **Step 3: Commit**

```bash
cd /Users/hibikipr/Developer/ntfy-ios
git add ntfy/Persistence/Store.swift
git commit -m "Add Store.saveIcon for persisting per-topic emoji"
```

---

### Task 3: Extend `TopicAvatarView` to render an emoji

**Files:**
- Modify: `ntfy/Views/Subscriptions/SubscriptionListView.swift` (the `TopicAvatarView` struct, currently lines 259-282)

**Interfaces:**
- Produces: `TopicAvatarView(name: String, emoji: String? = nil)` — later tasks (Task 4) pass `subscription.icon` as `emoji`.

- [ ] **Step 1: Update `TopicAvatarView`**

Replace the current `TopicAvatarView` struct:

```swift
struct TopicAvatarView: View {
    let name: String

    private var initial: String {
        String(name.first ?? "?").uppercased()
    }

    private var color: Color {
        let hash = abs(name.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.85)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
            Text(initial)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
```

with:

```swift
struct TopicAvatarView: View {
    let name: String
    var emoji: String? = nil

    private var initial: String {
        String(name.first ?? "?").uppercased()
    }

    private var color: Color {
        let hash = abs(name.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.85)
    }

    var body: some View {
        if let emoji, !emoji.isEmpty {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
        } else {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
                Text(initial)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}
```

Note: the existing call site at `SubscriptionItemRowView`'s `TopicAvatarView(name: subscription.topicName())` (line 180) does not need to change in this task — `emoji` defaults to `nil`, so it keeps rendering exactly as before.

- [ ] **Step 2: Build to verify it compiles and existing rows are unchanged**

Run: `cd /Users/hibikipr/Developer/ntfy-ios && xcodebuild build -scheme ntfy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

Expected: exit status 0, no output.

Manual check: install and launch on the simulator —

```bash
xcrun simctl install "iPhone 17 Pro" /Users/hibikipr/Library/Developer/Xcode/DerivedData/ntfy-*/Build/Products/Debug-iphonesimulator/ntfy.app
xcrun simctl launch "iPhone 17 Pro" io.heckel.ntfy
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/topic-avatars-unchanged.png
```

Open `/tmp/topic-avatars-unchanged.png` and confirm every topic row still shows its colored circle + initial letter exactly as before (no row has an `icon` set yet, so nothing should visually change).

- [ ] **Step 3: Commit**

```bash
cd /Users/hibikipr/Developer/ntfy-ios
git add ntfy/Views/Subscriptions/SubscriptionListView.swift
git commit -m "Add emoji rendering support to TopicAvatarView"
```

---

### Task 4: Wire `subscription.icon` into the row's avatar

**Files:**
- Modify: `ntfy/Views/Subscriptions/SubscriptionListView.swift` (the `SubscriptionItemRowView.body`, currently line 180)

**Interfaces:**
- Consumes: `TopicAvatarView(name:emoji:)` (Task 3), `Subscription.icon: String?` (Task 1).

- [ ] **Step 1: Pass the icon through**

In `SubscriptionItemRowView.body`, change:

```swift
        HStack(spacing: 12) {
            TopicAvatarView(name: subscription.topicName())
```

to:

```swift
        HStack(spacing: 12) {
            TopicAvatarView(name: subscription.topicName(), emoji: subscription.icon)
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd /Users/hibikipr/Developer/ntfy-ios && xcodebuild build -scheme ntfy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

Expected: exit status 0, no output. There is still no way to set `icon` yet (that's Task 5-6), so behavior is unchanged until then — this task only wires the data flow.

- [ ] **Step 3: Commit**

```bash
cd /Users/hibikipr/Developer/ntfy-ios
git add ntfy/Views/Subscriptions/SubscriptionListView.swift
git commit -m "Pass subscription.icon into the topic row's avatar"
```

---

### Task 5: Build the `TopicIconEditorView` sheet

**Files:**
- Create: `ntfy/Views/Subscriptions/TopicIconEditorView.swift`

**Interfaces:**
- Consumes: `Store.saveIcon(for:icon:)` (Task 2), `TopicAvatarView(name:emoji:)` (Task 3).
- Produces: `TopicIconEditorView(subscription: Subscription)` — Task 6 presents this in a `.sheet`.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct TopicIconEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subscription: Subscription
    @State private var iconText: String

    init(subscription: Subscription) {
        self.subscription = subscription
        _iconText = State(initialValue: subscription.icon ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TopicAvatarView(name: subscription.topicName(), emoji: iconText.isEmpty ? nil : iconText)
                    .scaleEffect(2)
                    .padding(.top, 24)

                VStack(spacing: 8) {
                    TextField("Emoji", text: $iconText)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: iconText) { newValue in
                            if let last = newValue.last {
                                iconText = String(last)
                            }
                            store.saveIcon(for: subscription, icon: iconText)
                        }

                    Text("Tap the field, then tap the globe/emoji key on the keyboard to pick one.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                if !iconText.isEmpty {
                    Button(role: .destructive) {
                        iconText = ""
                        store.saveIcon(for: subscription, icon: nil)
                    } label: {
                        Text("Remove")
                    }
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle(subscription.topicName())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TopicIconEditorView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview
        let subscription = store.makeSubscription(store.context, "stats", Store.sampleMessages["stats"]!)
        TopicIconEditorView(subscription: subscription)
            .environment(\.managedObjectContext, store.context)
            .environmentObject(store)
    }
}
```

Note on `onChange(of:)` signature: this file uses the single-parameter closure form (`{ newValue in ... }`), matching the iOS 16-compatible form already used elsewhere in this codebase (see `SubscriptionListView.swift`'s `.onChange(of: delegate.selectedBaseUrl) { newValue in ... }`).

- [ ] **Step 2: Register the new file with the Xcode project**

This project uses a manually-maintained `project.pbxproj` (no `PBXFileSystemSynchronizedRootGroup`), so new files must be registered by hand or Xcode won't compile them. Generate three unique 24-character hex IDs not already present in the file:

```bash
cd /Users/hibikipr/Developer/ntfy-ios
for i in 1 2; do
  id=$(python3 -c "import random; print(''.join(random.choice('0123456789ABCDEF') for _ in range(24)))")
  grep -q "$id" ntfy.xcodeproj/project.pbxproj && echo "COLLISION, regenerate" || echo "$id"
done
```

Using the two generated IDs (call them `FILEREF_ID` and `BUILDFILE_ID`), make these edits to `ntfy.xcodeproj/project.pbxproj`:

1. Add a `PBXBuildFile` entry next to the existing `SubscriptionAddView.swift in Sources` entry (search for it to find the right section):
```
		<BUILDFILE_ID> /* TopicIconEditorView.swift in Sources */ = {isa = PBXBuildFile; fileRef = <FILEREF_ID> /* TopicIconEditorView.swift */; };
```

2. Add a `PBXFileReference` entry next to `SubscriptionAddView.swift`'s file reference:
```
		<FILEREF_ID> /* TopicIconEditorView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TopicIconEditorView.swift; sourceTree = "<group>"; };
```

3. Add `<FILEREF_ID> /* TopicIconEditorView.swift */,` to the `Subscriptions` `PBXGroup`'s `children` list (the group containing `SubscriptionAddView.swift` and `SubscriptionListView.swift`).

4. Add `<BUILDFILE_ID> /* TopicIconEditorView.swift in Sources */,` to the `ntfy` target's `PBXSourcesBuildPhase` `files` list (search for `SubscriptionAddView.swift in Sources` inside the `Sources` phase and add the new line next to it).

- [ ] **Step 3: Build to verify it compiles**

Run: `cd /Users/hibikipr/Developer/ntfy-ios && xcodebuild build -scheme ntfy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

Expected: exit status 0, no output. If you see `error: cannot find 'TopicIconEditorView' in scope` or similar, re-check Step 2 — a common mistake is missing the `Sources` build phase entry specifically.

- [ ] **Step 4: Commit**

```bash
cd /Users/hibikipr/Developer/ntfy-ios
git add ntfy/Views/Subscriptions/TopicIconEditorView.swift ntfy.xcodeproj/project.pbxproj
git commit -m "Add TopicIconEditorView sheet for setting a topic's emoji"
```

---

### Task 6: Open the editor from the avatar tap

**Files:**
- Modify: `ntfy/Views/Subscriptions/SubscriptionListView.swift` (the `SubscriptionItemRowView` struct, currently lines 158-212)

**Interfaces:**
- Consumes: `TopicIconEditorView(subscription:)` (Task 5).

- [ ] **Step 1: Add sheet state and wrap the avatar in its own tap target**

Replace the current `SubscriptionItemRowView`:

```swift
struct SubscriptionItemRowView: View {
    @ObservedObject var subscription: Subscription
    @StateObject private var notificationsModel: NotificationsObservable

    init(subscription: Subscription) {
        self.subscription = subscription
        _notificationsModel = StateObject(wrappedValue: NotificationsObservable(subscriptionID: subscription.objectID))
    }

    private var isDefaultServer: Bool {
        guard let baseUrl = subscription.baseUrl else { return true }
        return normalizeBaseUrl(baseUrl) == normalizeBaseUrl(Config.appBaseUrl)
    }

    // notificationsModel.notifications is already sorted by time descending
    private var unreadCount: Int {
        notificationsModel.notifications.reduce(0) { $1.isRead ? $0 : $0 + 1 }
    }

    var body: some View {
        let totalNotificationCount = notificationsModel.notifications.count
        HStack(spacing: 12) {
            TopicAvatarView(name: subscription.topicName(), emoji: subscription.icon)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(subscription.topicName())
                            .font(.headline)
                            .lineLimit(1)
                        if !isDefaultServer, let baseUrl = subscription.baseUrl {
                            Text(shortUrl(url: baseUrl))
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(notificationsModel.notifications.first?.shortDateTime() ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("\(totalNotificationCount) notification\(totalNotificationCount != 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    if unreadCount > 0 {
                        Spacer()
                        UnreadDotView()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

with:

```swift
struct SubscriptionItemRowView: View {
    @ObservedObject var subscription: Subscription
    @StateObject private var notificationsModel: NotificationsObservable
    @State private var showIconEditor = false

    init(subscription: Subscription) {
        self.subscription = subscription
        _notificationsModel = StateObject(wrappedValue: NotificationsObservable(subscriptionID: subscription.objectID))
    }

    private var isDefaultServer: Bool {
        guard let baseUrl = subscription.baseUrl else { return true }
        return normalizeBaseUrl(baseUrl) == normalizeBaseUrl(Config.appBaseUrl)
    }

    // notificationsModel.notifications is already sorted by time descending
    private var unreadCount: Int {
        notificationsModel.notifications.reduce(0) { $1.isRead ? $0 : $0 + 1 }
    }

    var body: some View {
        let totalNotificationCount = notificationsModel.notifications.count
        HStack(spacing: 12) {
            Button {
                showIconEditor = true
            } label: {
                TopicAvatarView(name: subscription.topicName(), emoji: subscription.icon)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(subscription.topicName())
                            .font(.headline)
                            .lineLimit(1)
                        if !isDefaultServer, let baseUrl = subscription.baseUrl {
                            Text(shortUrl(url: baseUrl))
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(notificationsModel.notifications.first?.shortDateTime() ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("\(totalNotificationCount) notification\(totalNotificationCount != 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    if unreadCount > 0 {
                        Spacer()
                        UnreadDotView()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showIconEditor) {
            TopicIconEditorView(subscription: subscription)
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd /Users/hibikipr/Developer/ntfy-ios && xcodebuild build -scheme ntfy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

Expected: exit status 0, no output.

- [ ] **Step 3: Manual end-to-end verification**

This step needs a human with touch/accessibility access to the simulator or a device — the agent sandbox used earlier in this project's history had no tap/UI automation available, so this cannot be scripted. Install and launch the app, then:

1. Tap the avatar circle on any topic row. **Expected:** the `TopicIconEditorView` sheet opens (not the topic's notification list).
2. Tap elsewhere on that same row (the topic name or timestamp). **Expected:** it still navigates into the topic's notification list as before.
3. In the sheet, tap the text field, switch to the emoji keyboard (globe/emoji key), and pick an emoji. **Expected:** the preview avatar at the top of the sheet updates immediately to show that emoji with no colored background.
4. Tap "Done". **Expected:** back on "Subscribed topics", that topic's row now shows the emoji instead of the colored letter.
5. Pick a multi-codepoint emoji (e.g. a flag or a family emoji with skin tone modifiers). **Expected:** it displays as one complete glyph, not a broken/partial character.
6. Re-open the editor on that topic and tap "Remove". **Expected:** the preview reverts to the colored letter avatar, and the "Remove" button itself disappears (it's only shown when an icon is set).
7. Tap "Done". **Expected:** the topic row on "Subscribed topics" now shows the colored letter avatar again.
8. Confirm no other topic's avatar changed in this process.

- [ ] **Step 4: Commit**

```bash
cd /Users/hibikipr/Developer/ntfy-ios
git add ntfy/Views/Subscriptions/SubscriptionListView.swift
git commit -m "Open TopicIconEditorView when tapping a topic's avatar"
```

---

## Self-Review Notes

- **Spec coverage:** data model (Task 1), persistence (Task 2), row rendering fallback (Task 3), wiring (Task 4), editor sheet incl. remove/done (Task 5), entry point via avatar tap (Task 6) — all spec sections have a task.
- **Type consistency:** `Store.saveIcon(for:icon:)` (Task 2) is called with that exact signature in `TopicIconEditorView` (Task 5). `TopicAvatarView(name:emoji:)` (Task 3) is called with that exact signature in Task 4 and Task 5/6. `TopicIconEditorView(subscription:)` (Task 5) is called with that exact signature in Task 6.
- **No test target:** every task substitutes a build check plus a concrete manual verification for the automated test cycle this skill normally prescribes, since the project has no XCTest target and adding one is out of scope for this feature.
