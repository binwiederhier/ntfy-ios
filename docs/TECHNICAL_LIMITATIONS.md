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
