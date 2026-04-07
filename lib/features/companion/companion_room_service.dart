import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Outcome of checking whether a companion can join a room (after auth).
enum CompanionJoinCheck {
  ok,
  notFound,
  alreadyEnded,
}

/// First companion to claim an open walk request wins.
enum CompanionClaimResult {
  ok,
  notFound,
  taken,
  ownRequest,
}

/// Firestore paths for companion video signaling. Separate from heatmap / incidents.
///
/// - `companion_rooms/{roomCode}` — WebRTC signaling + room lifecycle.
/// - `companion_requests/{roomCode}` — published when someone needs a walk;
///   companions see `status == open` and tap to answer (claim).
class CompanionRoomService {
  CompanionRoomService._();

  static CollectionReference<Map<String, dynamic>> get _rooms =>
      FirebaseFirestore.instance.collection('companion_rooms');

  static CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance.collection('companion_requests');

  static String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static Future<User> ensureSignedIn() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
    }
    return user!;
  }

  /// True when Android/Console setup is incomplete ([CONFIGURATION_NOT_FOUND]).
  static bool isAuthConfigurationMissing(FirebaseAuthException e) {
    final msg = e.message ?? '';
    return msg.contains('CONFIGURATION_NOT_FOUND');
  }

  /// Shown in-app when [isAuthConfigurationMissing] is true.
  static const String authConfigurationHelp = 'Firebase could not load Authentication for this app.\n\n'
      'Do this in order:\n'
      '1) Firebase Console → Build → Authentication → Get started → Sign-in method → turn ON Anonymous.\n'
      '2) Project settings → Your apps → Android (com.example.safepath_campus) → Add fingerprint → add your debug SHA-1, '
      'then Download google-services.json and replace android/app/google-services.json.\n'
      '   (Windows debug SHA-1: run keytool -list -v -keystore "%USERPROFILE%\\.android\\debug.keystore" '
      '-alias androiddebugkey -storepass android -keypass android)\n'
      '3) Google Cloud Console (same project) → APIs & Services → Library → enable Identity Toolkit API.\n'
      '4) flutter clean, then run the app again.\n\n'
      'An empty "oauth_client" array in google-services.json often means SHA-1 was not registered yet.';

  /// Walker creates a room and publishes an open request so others can answer it.
  static Future<String> createWalkRoom() async {
    await ensureSignedIn();
    final hostUid = FirebaseAuth.instance.currentUser!.uid;
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = generateRoomCode();
      final roomRef = _rooms.doc(code);
      final reqRef = _requests.doc(code);
      final snap = await roomRef.get();
      if (snap.exists) continue;

      final batch = FirebaseFirestore.instance.batch();
      batch.set(roomRef, {
        'createdAt': FieldValue.serverTimestamp(),
        'hostUid': hostUid,
        'status': 'waiting',
      });
      batch.set(reqRef, {
        'roomCode': code,
        'hostUid': hostUid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });
      await batch.commit();
      return code;
    }
    throw StateError('Could not allocate room code');
  }

  /// Live list of walks waiting for a companion (same [roomCode] as join-by-code).
  static Stream<QuerySnapshot<Map<String, dynamic>>> openWalkRequestsStream() {
    return _requests
        .where('status', isEqualTo: 'open')
        .snapshots();
  }

  /// Atomically marks one open request as taken by the current user (guest).
  static Future<CompanionClaimResult> tryClaimOpenRequest(String roomCode) async {
    await ensureSignedIn();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _requests.doc(_normalize(roomCode));

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) return CompanionClaimResult.notFound;
      final data = snap.data()!;
      final status = data['status'] as String? ?? '';
      if (status != 'open') return CompanionClaimResult.taken;
      final hostUid = data['hostUid'] as String? ?? '';
      if (hostUid == uid) return CompanionClaimResult.ownRequest;

      transaction.update(ref, {
        'status': 'matched',
        'matchedUid': uid,
        'matchedAt': FieldValue.serverTimestamp(),
      });
      return CompanionClaimResult.ok;
    });
  }

  static Future<bool> roomExists(String code) async {
    final snap = await _rooms.doc(_normalize(code)).get();
    return snap.exists;
  }

  /// Call before joining: signs in anonymously (required by Firestore rules), then validates the room.
  static Future<CompanionJoinCheck> checkJoinable(String code) async {
    await ensureSignedIn();
    final snap = await _rooms.doc(_normalize(code)).get();
    if (!snap.exists) return CompanionJoinCheck.notFound;
    final status = snap.data()?['status'] as String? ?? '';
    if (status == 'ended') return CompanionJoinCheck.alreadyEnded;
    return CompanionJoinCheck.ok;
  }

  static String _normalize(String code) => code.trim().toUpperCase();

  static Future<void> markRoomEnded(String code) async {
    final n = _normalize(code);
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_rooms.doc(n), {
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _requests.doc(n),
      {
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}
