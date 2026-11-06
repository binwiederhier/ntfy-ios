# Notification icons and Live Activities

Both work for messages published to ntfy.sh directly, and for self-hosted servers that relay through ntfy.sh
(`upstream-base-url`), because the Notification Service Extension fetches the full message from the server.

## Notification icons

A message's `X-Icon` (or `Icon`) URL is shown as the sender avatar of the notification, the way chat apps show a
profile picture. If a message has no icon, the app uses the icon set for the topic (topic screen, `...` menu,
"Notification icon"). If neither exists, the notification looks like before.

```sh
curl -H "Title: Disk almost full" \
     -H "X-Icon: https://example.com/icons/server.png" \
     -d "93% used on /data" \
     ntfy.sh/mytopic
```

The extension downloads the icon (with the topic's credentials if the icon lives on the same server), scales it to
256 px, caches it in the app group, and turns the notification into a communication notification
(`INSendMessageIntent` with an `INPerson` whose image is the icon). The sender name is the notification title.

This needs the `com.apple.developer.usernotifications.communication` entitlement. If iOS rejects the communication
notification, the icon is attached as an image instead. A message with its own image attachment keeps that image.

## Live Activities

Messages with an `activity=<id>` tag start, update and end a Live Activity (lock screen and Dynamic Island).

| Tag | Meaning |
| --- | --- |
| `activity=<id>` | Required. Identifies the activity within the topic. |
| `state=start\|update\|end` | Optional, default `update`. An update for an activity that doesn't exist yet starts it. |
| `progress=<0-100>` | Optional. Shows a progress bar and percentage. |

The title becomes the activity title, the message body its status line, and the icon (`X-Icon`, or the topic icon)
its icon. Updates keep the previous icon if they don't send one.

```sh
curl -H "Title: Build #42" -H "Tags: activity=build-42,state=start,progress=0" -d "Queued" ntfy.sh/mytopic
curl -H "Title: Build #42" -H "Tags: activity=build-42,progress=40" -d "Compiling" ntfy.sh/mytopic
curl -H "Title: Build #42" -H "Tags: activity=build-42,state=end,progress=100" -d "Done in 4m 12s" ntfy.sh/mytopic
```

Update and end messages still arrive as notifications (dropping them needs Apple's notification filtering
entitlement), but they are delivered silently and without a banner. Start messages arrive as normal notifications.

### How updates reach the activity

Everything runs on the device, without ActivityKit push tokens or server changes:

1. **Starting** an activity needs the app in the foreground (an iOS rule). A `start` that arrives in the background
   shows up as a normal notification. Tapping it opens ntfy, which starts the activity.
2. **Updates and ends** are handled in the background. The Notification Service Extension can't touch the app's
   activities (they belong to the bundle that started them), so it queues the command in the app group, starts a
   tiny background download (`/v1/health` on the message's server) that begins 3 seconds later, and exits.
   Because the extension is gone when the download finishes, iOS relaunches ntfy in the background, and the app
   applies the queue. Tested on iOS 26: the activity changes about 4.5 seconds after the notification arrives.
3. iOS never relaunches an app that was force-quit from the app switcher. After a force-quit, updates wait until
   ntfy is opened again. The app also applies queued commands when it becomes active, after pull-to-refresh, and on
   the `~poll` background push.

The new widget extension has the bundle ID `io.heckel.ntfy.LiveActivity` and needs the `group.io.heckel.ntfy` app
group, so it can read the icons downloaded by the app and the extension.
