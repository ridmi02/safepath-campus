import 'dart:developer' as developer;

/// Central place to add Firebase-related interactions for the app.
/// Currently a lightweight stub so the UI can depend on it without
/// requiring Firebase to be wired up yet.
class FirebaseService {
  const FirebaseService();

  Future<void> logSosActivated() async {
    // In a future iteration this can send an event to Firebase Analytics
    // or write to Firestore / Realtime Database.
    developer.log('SOS activated', name: 'FirebaseService');
  }
}

