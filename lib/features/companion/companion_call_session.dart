import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'companion_room_service.dart';

typedef CompanionConnectionCallback = void Function(RTCPeerConnectionState state);
typedef CompanionErrorCallback = void Function(String message);

/// WebRTC + Firestore signaling for a single companion call.
///
/// Uses collection `companion_rooms/{roomId}` with fields `offer` / `answer` (maps with `sdp`, `type`)
/// and subcollections `host_ice` / `guest_ice` for trickle ICE.
class CompanionCallSession {
  CompanionCallSession({
    required String roomId,
    required this.isHost,
    this.onConnectionState,
    this.onError,
  }) : roomId = roomId.trim().toUpperCase();

  final String roomId;
  final bool isHost;
  final CompanionConnectionCallback? onConnectionState;
  final CompanionErrorCallback? onError;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _remoteIceSub;

  final Set<String> _seenIceDocIds = {};
  final List<RTCIceCandidate> _pendingRemoteIce = [];

  bool _remoteAnswerApplied = false;
  bool _remoteOfferApplied = false;
  bool _ended = false;

  static Map<String, dynamic> get _rtcConfig => {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

  Future<void> start() async {
    await CompanionRoomService.ensureSignedIn();
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
        },
      });
    } catch (e, st) {
      debugPrint('getUserMedia failed: $e\n$st');
      onError?.call('Camera or microphone permission is required.');
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      rethrow;
    }

    localRenderer.srcObject = _localStream;

    _pc = await createPeerConnection(_rtcConfig);
    _pc!.onConnectionState = (state) {
      onConnectionState?.call(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onError?.call('Connection failed. Try ending the call and reconnecting.');
      }
    };

    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      }
    };

    _pc!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate == null || candidate.candidate == null || candidate.candidate!.isEmpty) {
        return;
      }
      unawaited(_sendIceCandidate(candidate));
    };

    for (final t in _localStream!.getTracks()) {
      await _pc!.addTrack(t, _localStream!);
    }

    if (isHost) {
      await _startHostSignaling();
    } else {
      await _startGuestSignaling();
    }
  }

  bool get isEnded => _ended;

  Future<void> _startHostSignaling() async {
    _listenRemoteIce('guest_ice');

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    await FirebaseFirestore.instance.collection('companion_rooms').doc(roomId).update({
      'offer': {'type': offer.type, 'sdp': offer.sdp},
      'status': 'negotiating',
    });

    _roomSub = FirebaseFirestore.instance
        .collection('companion_rooms')
        .doc(roomId)
        .snapshots()
        .listen((snap) async {
      if (_ended) return;
      final data = snap.data();
      if (data == null) return;
      if ((data['status'] as String?) == 'ended') {
        onError?.call('The walk ended.');
        return;
      }
      if (_remoteAnswerApplied) return;
      final answer = data['answer'];
      if (answer is! Map) return;
      final sdp = answer['sdp'] as String?;
      final type = answer['type'] as String?;
      if (sdp == null || type == null) return;

      _remoteAnswerApplied = true;
      try {
        await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
        await _flushPendingIce();
      } catch (e, st) {
        debugPrint('setRemoteDescription (answer): $e\n$st');
        onError?.call('Could not complete the video handshake.');
      }
    });
  }

  Future<void> _startGuestSignaling() async {
    _listenRemoteIce('host_ice');

    _roomSub = FirebaseFirestore.instance
        .collection('companion_rooms')
        .doc(roomId)
        .snapshots()
        .listen((snap) async {
      if (_ended) return;
      final data = snap.data();
      if (data == null) return;
      if ((data['status'] as String?) == 'ended') {
        onError?.call('The walk ended.');
        return;
      }
      if (_remoteOfferApplied) return;
      final offer = data['offer'];
      if (offer is! Map) return;
      final sdp = offer['sdp'] as String?;
      final type = offer['type'] as String?;
      if (sdp == null || type == null) return;

      _remoteOfferApplied = true;
      try {
        await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
        await _flushPendingIce();

        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        await FirebaseFirestore.instance.collection('companion_rooms').doc(roomId).update({
          'answer': {'type': answer.type, 'sdp': answer.sdp},
          'status': 'connected',
        });
      } catch (e, st) {
        debugPrint('guest handshake: $e\n$st');
        onError?.call('Could not join the walk. Check the code and try again.');
      }
    });
  }

  void _listenRemoteIce(String remoteCollection) {
    _remoteIceSub?.cancel();
    _remoteIceSub = FirebaseFirestore.instance
        .collection('companion_rooms')
        .doc(roomId)
        .collection(remoteCollection)
        .snapshots()
        .listen((snap) async {
      if (_ended || _pc == null) return;
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final id = change.doc.id;
        if (_seenIceDocIds.contains(id)) continue;
        _seenIceDocIds.add(id);

        final d = change.doc.data();
        if (d == null) continue;
        final cand = d['candidate'] as String?;
        if (cand == null) continue;
        final mid = d['sdpMid'] as String?;
        final mline = d['sdpMLineIndex'];
        final idx = mline is int ? mline : (mline is num ? mline.toInt() : null);
        final ice = RTCIceCandidate(cand, mid, idx);

        final remote = await _pc!.getRemoteDescription();
        if (remote == null) {
          _pendingRemoteIce.add(ice);
        } else {
          try {
            await _pc!.addCandidate(ice);
          } catch (e, st) {
            debugPrint('addCandidate: $e\n$st');
          }
        }
      }
    });
  }

  Future<void> _flushPendingIce() async {
    if (_pc == null) return;
    final pending = List<RTCIceCandidate>.from(_pendingRemoteIce);
    _pendingRemoteIce.clear();
    for (final ice in pending) {
      try {
        await _pc!.addCandidate(ice);
      } catch (e, st) {
        debugPrint('flush ICE: $e\n$st');
      }
    }
  }

  Future<void> _sendIceCandidate(RTCIceCandidate c) async {
    if (_ended) return;
    final col = isHost ? 'host_ice' : 'guest_ice';
    try {
      await FirebaseFirestore.instance
          .collection('companion_rooms')
          .doc(roomId)
          .collection(col)
          .add({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
        'uid': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e, st) {
      debugPrint('sendIce: $e\n$st');
    }
  }

  Future<void> endCall() async {
    if (_ended) return;
    _ended = true;

    await _roomSub?.cancel();
    _roomSub = null;
    await _remoteIceSub?.cancel();
    _remoteIceSub = null;

    for (final t in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      t.stop();
    }
    await _localStream?.dispose();
    _localStream = null;

    await _pc?.close();
    _pc = null;

    try {
      localRenderer.srcObject = null;
      await localRenderer.dispose();
    } catch (_) {}
    try {
      remoteRenderer.srcObject = null;
      await remoteRenderer.dispose();
    } catch (_) {}

    if (isHost) {
      try {
        await CompanionRoomService.markRoomEnded(roomId);
      } catch (_) {}
    }
  }
}
