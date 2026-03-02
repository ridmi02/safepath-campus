// Replace the placeholder values below with your real Firebase project values.
// You can generate a proper `firebase_options.dart` by running the
// FlutterFire CLI: `dart pub global activate flutterfire_cli` then
// `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Basic placeholder options. Replace these with values from your
    // Firebase console (or run `flutterfire configure`).
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIza...YOUR_API_KEY...',
        appId: '1:000:web:000000000000',
        messagingSenderId: '000000000000',
        projectId: 'your-project-id',
        authDomain: 'your-project-id.firebaseapp.com',
        storageBucket: 'your-project-id.appspot.com',
        measurementId: 'G-XXXXXXX',
      );
    }

    // Android / iOS placeholders. Fill as necessary for mobile testing.
    return const FirebaseOptions(
      apiKey: 'AIza...YOUR_API_KEY...',
      appId: '1:000:android:000000000000',
      messagingSenderId: '000000000000',
      projectId: 'your-project-id',
    );
  }
}
