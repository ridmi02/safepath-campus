import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Firestore only carries signaling; video/audio need WebRTC.
/// On university Wi‑Fi and especially **mobile data**, direct peer paths often fail
/// unless you add **TURN** (relay). TURN always needs server URLs + credentials from a provider.

bool isCompanionTurnConfigured() {
  try {
    final uri = dotenv.env['COMPANION_TURN_URI']?.trim();
    final user = dotenv.env['COMPANION_TURN_USERNAME']?.trim();
    final cred = dotenv.env['COMPANION_TURN_CREDENTIAL']?.trim();
    return uri != null &&
        uri.isNotEmpty &&
        user != null &&
        user.isNotEmpty &&
        cred != null &&
        cred.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// STUN (discovery) + optional TURN (relay) from `.env`.
List<Map<String, dynamic>> buildCompanionIceServers() {
  final servers = <Map<String, dynamic>>[
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
  ];

  if (!isCompanionTurnConfigured()) {
    return servers;
  }

  try {
    final urls = dotenv.env['COMPANION_TURN_URI']!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (urls.isNotEmpty) {
      servers.add({
        'urls': urls.length == 1 ? urls.first : urls,
        'username': dotenv.env['COMPANION_TURN_USERNAME']!.trim(),
        'credential': dotenv.env['COMPANION_TURN_CREDENTIAL']!.trim(),
      });
    }
  } catch (_) {}

  return servers;
}
