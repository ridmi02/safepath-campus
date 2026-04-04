import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for this app.
///
/// **Android** matches [android/app/google-services.json] (project `safepathcampus`).
/// For **Web** and **iOS**, after you add those apps in Firebase, either paste the real
/// `appId` values from Project settings, or run: `dart run flutterfire configure`
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
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return android;
    }
  }

  /// Add your Web app in Firebase → Project settings → scroll to Web apps → copy `appId` (GOOGLE_APP_ID).
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC4n4ypb3r_sxVTftjJG7j-O_YP3RbgwXk',
    appId: '1:685856606892:web:REPLACE_WITH_WEB_APP_ID',
    messagingSenderId: '685856606892',
    projectId: 'safepathcampus',
    authDomain: 'safepathcampus.firebaseapp.com',
    storageBucket: 'safepathcampus.firebasestorage.app',
  );

  /// Same project as [google-services.json] (`safepathcampus`).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC4n4ypb3r_sxVTftjJG7j-O_YP3RbgwXk',
    appId: '1:685856606892:android:bb1dbd2c492563a2a06d09',
    messagingSenderId: '685856606892',
    projectId: 'safepathcampus',
    storageBucket: 'safepathcampus.firebasestorage.app',
  );

  /// Add iOS app in Firebase → download `GoogleService-Info.plist` → copy `GOOGLE_APP_ID`, or use FlutterFire.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC4n4ypb3r_sxVTftjJG7j-O_YP3RbgwXk',
    appId: '1:685856606892:ios:REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '685856606892',
    projectId: 'safepathcampus',
    storageBucket: 'safepathcampus.firebasestorage.app',
    iosBundleId: 'com.example.safepathCampus',
  );
}
