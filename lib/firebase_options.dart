// File generated/maintained manually for WeSafe Firebase configuration.
// Do not commit API keys to public repositories.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return web;
    }
  }

  // Web Firebase config — wesafe-5676c project
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAVaPrUB4rb4h-XF1aTrM2BXjxdxbAXtOY',
    appId: '1:738523424070:web:32dd62755455c9f59ef147',
    messagingSenderId: '738523424070',
    projectId: 'wesafe-5676c',
    authDomain: 'wesafe-5676c.firebaseapp.com',
    storageBucket: 'wesafe-5676c.firebasestorage.app',
    measurementId: 'G-LQBP20PYDE',
  );

  // Android config — wesafe-5676c project
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAVaPrUB4rb4h-XF1aTrM2BXjxdxbAXtOY',
    appId: '1:738523424070:android:3d30fa9e6edf07ea9ef147',
    messagingSenderId: '738523424070',
    projectId: 'wesafe-5676c',
    storageBucket: 'wesafe-5676c.firebasestorage.app',
  );

  // iOS config — update appId when GoogleService-Info.plist is added
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAVaPrUB4rb4h-XF1aTrM2BXjxdxbAXtOY',
    appId: '1:738523424070:web:32dd62755455c9f59ef147',
    messagingSenderId: '738523424070',
    projectId: 'wesafe-5676c',
    storageBucket: 'wesafe-5676c.firebasestorage.app',
    iosBundleId: 'com.wesafe.app',
  );

  // macOS config
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAVaPrUB4rb4h-XF1aTrM2BXjxdxbAXtOY',
    appId: '1:738523424070:web:32dd62755455c9f59ef147',
    messagingSenderId: '738523424070',
    projectId: 'wesafe-5676c',
    storageBucket: 'wesafe-5676c.firebasestorage.app',
    iosBundleId: 'com.wesafe.app',
  );
}
