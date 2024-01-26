# Heart Beat Live iOS App
Official iOS application of HeartBeatLive project.
This app is written on Swift programming language and use SwiftUI framework.

## Configuration
Before launching application, you need to configure it.
First, add `GoogleService-Info.plist` file to `./HeartBeatLive` folder. You may download this file from Firebase Console.
Then open `Config.release.xcconfig` file and edit configuration values.

| Property name   | Description     |
| --------------- | --------------- |
| `SERVER_SCHEME` | Server scheme, that application should use. Use `https` on production. |
| `SERVER_HOST`   | Server host, on which we should make all requests. May include port. |
