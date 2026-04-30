import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Object? _lastError;

  static Object? get lastError => _lastError;

  static bool get isInitialized => Firebase.apps.isNotEmpty;

  static Future<void> initialize() async {
    if (isInitialized) return;

    try {
      if (kIsWeb) {
        _lastError = UnsupportedError(
          'Firebase phone auth is not configured for web in this project.',
        );
        return;
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
          _lastError = null;
          return;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          if (DefaultFirebaseOptions.isAppleConfigured) {
            await Firebase.initializeApp(options: DefaultFirebaseOptions.apple);
          } else {
            await Firebase.initializeApp();
          }
          _lastError = null;
          return;
        case TargetPlatform.windows:
        case TargetPlatform.linux:
          _lastError = UnsupportedError(
            'Firebase phone auth is only configured for Android and iOS right now.',
          );
          return;
        case TargetPlatform.fuchsia:
          _lastError = UnsupportedError(
            'Firebase is not configured for Fuchsia in this project.',
          );
          return;
      }
    } catch (error) {
      _lastError = error;
      rethrow;
    }
  }
}
