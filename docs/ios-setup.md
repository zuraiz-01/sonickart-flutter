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
