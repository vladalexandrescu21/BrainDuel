import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ─── iOS ────────────────────────────────────────────────────────────────────
  // All values sourced from GoogleService-Info.plist (brainduel-7ee93)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCGXyRqDSyuzJoeJSGjh_tKuYDjm7LHC8o',
    appId: '1:585042937225:ios:e75e69e5f1ae831f328d58',
    messagingSenderId: '585042937225',
    projectId: 'brainduel-7ee93',
    storageBucket: 'brainduel-7ee93.firebasestorage.app',
    iosBundleId: 'com.brainduel.app',
    iosClientId: '585042937225-qnfnfui06uifb9tde05a7imup1lp9uke.apps.googleusercontent.com',
  );

  // ─── Android ────────────────────────────────────────────────────────────────
  // TODO: Add Android app in Firebase Console → Project Settings → Add app
  // Then replace these placeholders with values from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ANDROID_API_KEY',
    appId: 'REPLACE_ANDROID_APP_ID',
    messagingSenderId: '585042937225',
    projectId: 'brainduel-7ee93',
    storageBucket: 'brainduel-7ee93.firebasestorage.app',
  );

  // ─── Web ────────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBNGX3KogjeSpxVeDkWk3pUnjsYa3cRTz8',
    appId: '1:585042937225:web:4e7da18e5d7f1b55328d58',
    messagingSenderId: '585042937225',
    projectId: 'brainduel-7ee93',
    storageBucket: 'brainduel-7ee93.firebasestorage.app',
    authDomain: 'brainduel-7ee93.firebaseapp.com',
  );
}
