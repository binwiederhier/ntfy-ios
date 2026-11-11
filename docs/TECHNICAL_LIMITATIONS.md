#  ntfy.sh iOS - Technical Limitations

### No Foreground Services

Android can utilize foreground services to maintain a connection to the ntfy.sh / self-hosted server.
 
iOS doe not have any such feature, so the app can currently only rely on Firebase and background tasks.

### Background Tasks

iOS "intelligently" decides when to run background tasks, NOT when you schedule / request them.

Taken from [Background execution demystified](https://developer.apple.com/videos/play/wwdc2020/10063/), you would expect a "periodic" background task to be executed every 2 hours. In reality, iOS may decide to execute the background task at an irregular interval, sometimes not executing for hours at a time.

In my limited testing, I created a background app refresh task to gather new notifications periodically (every 15 minutes) poll the topics for new notifications. The end result was that my background task was executed only once in the day that I let it run.

This made me realize that background tasks are very unreliable in the context of ntfy.sh, where it would be best to periodically poll the topics for notifications. If the background task were to not execute for a longer period than notifications are cached, then it's possible that notifications would never make it to the app.

### Self-hosted Servers

Self-hosted servers are a tricky problem to solve.

Because the iOS app heavily almost exclusively on Firebase (unless you want to manually refresh every topic on your own to get the latest notifications), the self-hosted server would need to be running Firebase.

In addition to running firebase, the iOS users would need to build their own iOS app with their firebase credentials packaged in.

If we want to stick with the default (official) iOS app, and allow self-hosted servers to be used / subscribed to, the self-hosted server would need to relay any notifications to ntfy.sh, so that it may use the Firebase credentials/configuration there to properly send the notification to the iOS device.

### Critical Alerts

Critical alerts play a sound even if the device is muted or a Focus (e.g. Do Not Disturb) is active. Whether a message is delivered as a critical alert is decided by the publisher, via the `apple` options of the message (`X-Apple-Critical`, `X-Apple-Sound` and `X-Apple-Volume` headers on the ntfy server):

| `apple.critical` | Priority | Critical alert              |
| ---------------- | -------- | --------------------------- |
| `true`           | any      | Yes                         |
| `false`          | any      | No, even at max priority    |
| *(not set)*      | `5`      | Yes                         |
| *(not set)*      | `1`-`4`  | No                          |

There are a few things to be aware of:

- The app needs the [critical alerts entitlement][ios_critical_alerts], which has to be requested from Apple. Builds without it cannot deliver critical alerts.
- Critical alerts are only delivered if the "Critical Alerts" setting in the app is enabled, and if iOS has granted the critical alert permission. Otherwise the notification is delivered as a regular (time sensitive, for max priority) notification.
- The setting in the app is applied by the notification service extension. If the extension cannot process a notification (unknown subscription, failed poll request, timeout), iOS shows the original push notification as sent by the server. If the server marked it as critical and iOS has granted the permission, it is then delivered as a critical alert regardless of the setting in the app.
- The volume (`apple.volume`, greater than `0.0` and at most `1.0`) defaults to `1.0`.
- Custom sounds (`apple.sound`) are not bundled with the app yet, so every sound name currently plays the default critical sound. Sound names are looked up in the main app bundle and in the `Library/Sounds` folder of the app group container, with or without file extension (`.caf`, `.aiff`, `.wav`). To add a sound, add the file to the main app target.

[ios_critical_alerts]: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts
