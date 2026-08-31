import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

/// Default [FirebaseOptions] for use in initializing Firebase.
///
/// This is a skeleton/boilerplate file. When you set up your real Firebase project,
/// replace these with your actual keys from the Firebase Console or FlutterFire CLI.
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'MOCK_API_KEY_WEB',
    appId: '1:1234567890:web:1234567890',
    messagingSenderId: '1234567890',
    projectId: 'radio-over-mock',
    authDomain: 'radio-over-mock.firebaseapp.com',
    storageBucket: 'radio-over-mock.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBCv3QnSCp0QmexlP3sPXgc5ycXFnkNDNw',
    appId: '1:201441769052:android:29a21fff9dd02689c4d899',
    messagingSenderId: '201441769052',
    projectId: 'radio-over-lw-a7008',
    storageBucket: 'radio-over-lw-a7008.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA6B_4NUd_EvPyGREVjHngnQe86CuuW-70',
    appId: '1:201441769052:ios:4db8742852476de3c4d899',
    messagingSenderId: '201441769052',
    projectId: 'radio-over-lw-a7008',
    storageBucket: 'radio-over-lw-a7008.firebasestorage.app',
    iosBundleId: 'com.radioover.radioOver',
  );
}
