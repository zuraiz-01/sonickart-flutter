# iOS Setup

The Flutter iOS target is configured with bundle id `com.sonickart.app`, Google Maps startup, location/camera/photo usage descriptions, and CocoaPods settings for the current plugin set.

## Firebase

Firebase CLI access for project `sonickart-app` is required to generate the real iOS app config.

Use one of these options:

1. Add an iOS app in Firebase Console with bundle id `com.sonickart.app`, download `GoogleService-Info.plist`, and place it at:

   `ios/Runner/GoogleService-Info.plist`

2. Or run Flutter with Dart defines:

   ```sh
   flutter run --dart-define=SONICKART_IOS_FIREBASE_API_KEY=<ios-api-key> --dart-define=SONICKART_IOS_FIREBASE_APP_ID=<ios-app-id>
   ```

`ios/Runner/GoogleService-Info.plist.example` documents the expected plist shape.

## Local iOS Build

Run these on macOS:

```sh
flutter pub get
cd ios
pod install
cd ..
flutter run -d ios
```

Phone auth on iOS still requires the Firebase iOS app to be registered and the app's iOS auth settings/APNs setup to be completed in Firebase.

For SonicKart, the iOS phone-auth reCAPTCHA fallback is wired in `ios/Runner/Info.plist` with the Firebase Encoded App ID URL scheme:

`app-1-443982695818-ios-12de8aefe01c4976728c73`

If the Firebase iOS app is recreated, replace this value with the new Encoded App ID from Firebase Console and keep Background Modes enabled for `fetch` and `remote-notification`.
