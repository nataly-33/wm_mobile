import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase no configurado para web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no configurado para esta plataforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyADNthoBq3LNCdABfTj8efQyL-2ce9EWWM',
    appId: '1:1056382266421:android:9e993f71e7ad212a58957c',
    messagingSenderId: '1056382266421',
    projectId: 'wm-mobile-2bae8',
    storageBucket: 'wm-mobile-2bae8.firebasestorage.app',
  );
}
