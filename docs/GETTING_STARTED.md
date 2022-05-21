# ntfy.sh iOS - Getting Started with Development

## Requirements
Note: these requirements are strictly based off of my development on this app. There may be other versions of macOS / XCode that work. Feel free to test on other versions!

1. macOS Monterey or later
1. XCode 13.2+
1. A physical iOS device (for push notifications, I could not get them to work in the XCode simulator)
1. The [macOS development branch for ntfy](https://github.com/Copephobia/ntfy/tree/macos-development) (for APNS configuration)
1. Firebase account
1. Apple Developer license? (I forget if its possible to do testing without purchasing the license)

## Setup - Apple Developer

1. [Create a new key in Apple Developer Member Center](https://developer.apple.com/account/resources/authkeys/add)
  1. Select "Apple Push Notifications service (APNs)"
1. Download the newly created key (should have a file name similar to `AuthKey_ZZZZZZ.p8`, where `ZZZZZZ` is the **Key ID**)
1. Record your **Team ID** - it can be seen in the top-right corner of the page, or on your Account > Membership page

## Setup - Firebase

1. If you haven't already, create a Google / Firebase account
1. Visit the [Firebase console](https://console.firebase.google.com)
1. Create a new Firebase project:
  1. Enter a project name
  1. Disable Google Analytics (currently iOS app does not support analytics)
1. On the "Project settings" page, add an iOS app
  1. Apple bundle ID - "com.copephobia.ntfy-ios" (this can be changed to match XCode's ntfy.sh target > "Bundle Identifier" value)
  1. Register the app
  1. Download the config file - GoogleInfo.plist (this will need to be included in the ntfy-ios repository / XCode)
1. Generate a new service account private key for the ntfy server
  1. Go to "Project settings" > "Service accounts"
  1. Click "Generate new private key" to generate and download a private key to use for sending messages via the ntfy server

## Setup - ntfy server

1. Checkout the [macOS development branch for ntfy](https://github.com/Copephobia/ntfy/tree/macos-development)
1. If not already made, make the `/etc/ntfy/` directory and move the service account private key to that folder
1. Copy the `server/server.yml` file from the ntfy repository to `/etc/ntfy/`
1. Modify the `/etc/ntfy/server.yml` file `firebase-key-file` value to the path of the private key
1. Install go: `brew install go`
1. In the ntfy repository, run `make build-simple`

## Setup - XCode

1. Follow step 4 of [https://firebase.google.com/docs/ios/setup](Add Firebase to your Apple project) to install the firebase-ios-sdk in XCode, if it's not already present - you can select any packages in addition to Firebase Core / Firebase Messaging
1. Similarly, install the SQLite.swift package dependency in XCode
1. When running the debug build, ensure XCode is pointed to the connected iOS device - registering for push notifications does not work in the iOS simulators

## Useful resources

- https://www.raywenderlich.com/14958063-modern-efficient-core-data
- https://www.hackingwithswift.com/books/ios-swiftui/how-to-combine-core-data-and-swiftui
- https://stackoverflow.com/a/41783666/1440785
- https://stackoverflow.com/questions/47374903/viewing-core-data-data-from-your-app-on-a-device
- https://debashishdas3100.medium.com/save-push-notifications-to-coredata-userdefaults-ios-swift-5-ea074390b57
