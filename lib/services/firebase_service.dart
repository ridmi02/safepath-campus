import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Central place to add Firebase-related interactions for the app.
class FirebaseService {
  const FirebaseService();

  CollectionReference<Map<String, dynamic>> get _sosCollection =>
      FirebaseFirestore.instance.collection('sos_logs');

  Future<void> logSosActivated() async {
    try {
      await _sosCollection.add({
        'activatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      developer.log(
        'Failed to log SOS: $e',
        name: 'FirebaseService',
        stackTrace: st,
      );
    }
  }
}

