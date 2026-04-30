import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return apple;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase is only configured for Android and iOS in this project.',
        );
    }
  }

  static FirebaseOptions get firestoreRestOptions => currentPlatform;

  static bool get isAppleConfigured =>
      apple.apiKey.trim().isNotEmpty && apple.appId.trim().isNotEmpty;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBSrTFKYF8ZbuTsXa1EudjXpLgIILGK07s',
    appId: '1:443982695818:android:ee41e147a7bd12b6728c73',
    messagingSenderId: '443982695818',
    projectId: 'sonickart-app',
    storageBucket: 'sonickart-app.firebasestorage.app',
  );

  static const FirebaseOptions apple = FirebaseOptions(
    apiKey: 'AIzaSyCvyX5LD___3uc9fkpSMoLV3Du55E9cBtA',
    appId: '1:443982695818:ios:12de8aefe01c4976728c73',
    messagingSenderId: '443982695818',
    projectId: 'sonickart-app',
    storageBucket: 'sonickart-app.firebasestorage.app',
    iosBundleId: 'com.sonickart.app',
  );
}
