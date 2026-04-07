import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

/// Firestore logging for voice-activation flows only.
/// - [eventsCollectionName]: each SOS / panic trigger (optional [panicWord] snapshot).
/// - [voiceSettingsCollectionName]: current panic word per user (`voice_activation/{uid}`).
class VoiceActivationFirestoreService {
  VoiceActivationFirestoreService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String eventsCollectionName = 'voice_activation_events';
  static const String voiceSettingsCollectionName = 'voice_activation';

  /// Stores the active panic word for voice features (one doc per user).
  Future<void> savePanicWord(String word) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      debugPrint('VoiceActivationFirestore: Saving panic word for UID: $uid');
      await _firestore.collection(voiceSettingsCollectionName).doc(uid).set({
        'panicWord': word,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint(
        'VoiceActivationFirestore: panic word saved → '
        '$voiceSettingsCollectionName/$uid',
      );
    } on FirebaseException catch (e, st) {
      debugPrint(
        'VoiceActivationFirestore.savePanicWord [${e.code}]: ${e.message}\n$st',
      );
    } catch (e, st) {
      debugPrint('VoiceActivationFirestoreService.savePanicWord: $e\n$st');
    }
  }

  /// Records a voice-triggered event. Errors are logged only; does not throw.
  Future<void> logEvent({
    required String source,
    String? panicWord,
    double? latitude,
    double? longitude,
  }) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final ref = await _firestore.collection(eventsCollectionName).add({
        // This logs the voice activation event itself
        'source': source,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        if (panicWord != null && panicWord.trim().isNotEmpty)
          'panicWord': panicWord.trim(),
        ...?(latitude == null ? null : {'lat': latitude}),
        ...?(longitude == null ? null : {'lng': longitude}),
      });
      debugPrint(
        'VoiceActivationFirestore: saved doc ${ref.id} → collection "$eventsCollectionName"',
      );
    } on FirebaseException catch (e, st) {
      debugPrint(
        'VoiceActivationFirestoreService Firestore [${e.code}]: ${e.message}\n$st',
      );
    } catch (e, st) {
      debugPrint('VoiceActivationFirestoreService.logEvent: $e\n$st');
    }
  }
}
