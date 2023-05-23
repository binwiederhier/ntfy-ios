#  ntfy.sh iOS - Android Feature Parity

This document is to keep track of the feature parity between the iOS and Android ntfy.sh apps.

**Last Updated: 2023-05-23**

| Feature                               | iOS                | Android            | Notes                                                                                                         |
| ------------------------------------- | ------------------ | ------------------ | ------------------------------------------------------------------------------------------------------------- |
| Subscribe to default server topic     | :white_check_mark: | :white_check_mark: |
| Subscribe to self-hosted server topic | :white_check_mark: | :white_check_mark: | Reliable delivery only with [`upstream_base_url`][ntfy_ios_instant_notifications]                             |
| Instant delivery                      | :x:                | :white_check_mark: | Foreground services not possible in iOS                                                                       |
| Pause notifications                   | :x:                | :white_check_mark: | Will likely require [Filtering][ios_filtering] to prevent displaying notifications while still receiving them |
| Send test notification                | :white_check_mark: | :white_check_mark: | Not fully implemented                                                                                         |
| Unsubscribe from topic                | :white_check_mark: | :white_check_mark: |
| Delete notifications                  | :white_check_mark: | :white_check_mark: |
| Notification priority                 | :warning:          | :white_check_mark: | No priority filtering                                                                                         |
| Tags and emojis                       | :white_check_mark: | :white_check_mark: |
| Click action                          | :warning:          | :white_check_mark: | Only direct notification click                                                                                |
| Attachments                           | :warning:          | :white_check_mark: | Not fully implemented                                                                                         |
| User Authentication                   | :warning:          | :white_check_mark: |                                                                                                               |
| Dark mode                             | :white_check_mark: | :white_check_mark: | Dependent on iOS dark mode, may add override in                                                               |
| Logging                               | :x:                | :white_check_mark: | Not yet implemented                                                                                           |
| Share to topic                        | :x:                | :white_check_mark: | Not yet implemented                                                                                           |

[ios_filtering]: https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_usernotifications_filtering
[ntfy_ios_instant_notifications]: https://docs.ntfy.sh/config/#ios-instant-notifications
