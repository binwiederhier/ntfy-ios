#  ntfy.sh iOS - Android Feature Parity

This document is to keep track of the feature parity between the iOS and Android ntfy.sh apps.

**Last Updated: 2021-02-21**

| Feature | iOS | Android | Notes |
| --- | --- | --- | --- |
| Subscribe to default server topic | :white_check_mark: | :white_check_mark: |
| Subscribe to self-hosted server topic | :x: | :white_check_mark: | Not yet implemented |
| Instant delivery | :x: | :white_check_mark: | Foreground services not possible in iOS |
| Pause notifications | :x: | :white_check_mark: | Will likely require [Filtering](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_usernotifications_filtering) to prevent displaying notifications while still receiving them |
| Send test notification | :white_check_mark: | :white_check_mark: | Not fully implemented |
| Unsubscribe from topic | :white_check_mark: | :white_check_mark: |
| Delete notifications | :warning: | :white_check_mark: | Implemented, but needs improvement |
| Notification priority | :warning: | :white_check_mark: | Displays an exclamation mark in notification row for high.max priority, no changes to the actual push notification (sounds, vibrations), no  prioirty filtering |
| Tags and emojis | :white_check_mark: | :white_check_mark: |
| Click action | :x: | :white_check_mark: | Not yet implemented |
| Attachments | :warning: | :white_check_mark: | Not fully implemented |
| User Authentication | :warning: | :white_check_mark: | Not fully implemented |
| Dark mode | :white_check_mark: | :white_check_mark: | Dependent on iOS dark mode, may add override in |
| Logging | :x: | :white_check_mark: | Not yet implemented |
| Share to topic | :x: | :white_check_mark: | Not yet implemented |
