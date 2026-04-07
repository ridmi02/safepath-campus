import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'notification_service.dart';
import 'voice_activation_firestore_service.dart';
import '../firebase_options.dart';

class EmergencyAlertService {
  static bool _isAlertActive = false;
  static const String _contactsKey = 'emergency_contacts';
  static const String _panicWordKey = 'panic_word';
  static const String _voiceEnabledKey = 'voice_guardian_enabled';
  static const String _sensitivityKey = 'voice_sensitivity';
  static const String _hapticKey = 'haptic_feedback_enabled';
  static const String _voiceFeedbackKey = 'voice_feedback_enabled';
  static const String _recordAudioKey = 'record_audio_enabled';
  static const String _discreetModeKey = 'discreet_mode_enabled';
  static const String _customSosMessageKey = 'custom_sos_message';
  static const String _sosCountdownKey = 'sos_countdown_seconds';
  static const String _firestoreContactsCollection = 'EmergencyContacts';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool get isAlertActive => _isAlertActive;

  /// Ensures the current isolate has an authenticated user session.
  Future<User?> _ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
      } catch (e) {
        debugPrint('EmergencyAlertService: Anonymous sign-in failed: $e');
        debugPrint('EmergencyAlertService: Auth failed: $e');
        return null;
      }
    }
    return _auth.currentUser;
  }

  static List<Map<String, dynamic>> _decodeContactsList(List<String> rawList) {
    return rawList.map((item) {
      try {
        return Map<String, dynamic>.from(jsonDecode(item) as Map);
      } catch (e) {
        return {
          'phone': item,
          'name': 'Unknown',
          'relation': 'Emergency Contact',
          'id': item,
          'addedAt': DateTime.now().toIso8601String(),
        };
      }
    }).toList();
  }

  Future<void> _persistContactsAndSyncCloud(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _contactsKey,
      list.map((c) => jsonEncode(c)).toList(),
    );
    await _pushEmergencyContactsToFirestore(list);
  }

  /// Normalized phone for duplicate checks (digits only, optional leading country digit).
  static String normalizePhoneKey(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits;
  }

  Future<void> _pushEmergencyContactsToFirestore(
    List<Map<String, dynamic>> contacts,
  ) async {
    try {
      final user = await _ensureAuthenticated();
      if (user == null) return;

      final sanitized = contacts
          .where((c) => c['phone']?.toString().isNotEmpty ?? false) // Ensure valid phone numbers
          .map(
            (c) => <String, dynamic>{
              'id': c['id']?.toString() ?? '',
              'name': c['name']?.toString() ?? '',
              'phone': c['phone']?.toString() ?? '',
              'relation': c['relation']?.toString() ?? '',
              'addedAt': c['addedAt']?.toString() ?? '',
            },
          )
          .toList();

      debugPrint('EmergencyAlertService: Attempting to sync contacts for UID: ${user.uid}');
      await _firestore.collection(_firestoreContactsCollection).doc(user.uid).set({
        'emergencyContacts': sanitized,
        'emergencyContactsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint(
        'Emergency contacts synced to Firestore $_firestoreContactsCollection/${user.uid} (${sanitized.length})',
      );
    } catch (e) {
      debugPrint('Emergency contacts Firestore sync failed: $e');
    }
  }

  /// Get list of emergency contacts (local prefs; restores from Firestore if local empty).
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_contactsKey) ?? [];
    var list = _decodeContactsList(rawList);

    if (list.isEmpty) {
      try {
        final user = await _ensureAuthenticated();
        if (user != null) {
          debugPrint('EmergencyAlertService: Attempting to restore contacts for UID: ${user.uid}');
          final doc = await _firestore.collection(_firestoreContactsCollection).doc(user.uid).get();
          final cloud = doc.data()?['emergencyContacts'];
          if (cloud is List && cloud.isNotEmpty) {
            list = cloud
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            await prefs.setStringList(
              _contactsKey,
              list.map((c) => jsonEncode(c)).toList(),
            );
          }
        }
      } catch (e) {
        debugPrint('Restore emergency contacts from Firestore: $e');
      }
    }

    return list;
  }

  /// Whether [normalizedOrRawPhone] is already used by another contact.
  bool contactPhoneExists(
    List<Map<String, dynamic>> contacts,
    String phone, {
    String? ignoreNormalizedKey,
  }) {
    final key = normalizePhoneKey(phone);
    if (key.isEmpty) return false;
    for (final c in contacts) {
      final p = normalizePhoneKey((c['phone'] ?? '').toString());
      if (p.isEmpty) continue;
      if (ignoreNormalizedKey != null && p == ignoreNormalizedKey) continue;
      if (p == key) return true;
    }
    return false;
  }

  /// Add emergency contact phone number
  Future<void> addEmergencyContact(String name, String phone, String relation) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_contactsKey) ?? [];
    final list = _decodeContactsList(raw);

    final newContact = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name,
      'phone': phone,
      'relation': relation,
      'addedAt': DateTime.now().toIso8601String(),
    };
    list.add(newContact);
    await _persistContactsAndSyncCloud(list);

    await NotificationService.subscribeToEmergencyUpdates(phone);
  }

  /// Remove emergency contact
  Future<void> removeEmergencyContact(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_contactsKey) ?? [];
    final list = _decodeContactsList(raw);

    list.removeWhere((c) {
      final p = (c['phone'] ?? '').toString();
      return p == phoneNumber ||
          normalizePhoneKey(p) == normalizePhoneKey(phoneNumber);
    });

    await _persistContactsAndSyncCloud(list);

    await NotificationService.unsubscribeFromEmergencyUpdates(phoneNumber);
  }

  /// Set the custom panic word (e.g., "Help me")
  Future<void> setPanicWord(String word) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_panicWordKey, word);

    // Sync with Firebase Firestore (Users/{uid}.panicWord) — visible in Console
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('Users').doc(user.uid).set({
          'panicWord': word,
          'settingsUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('Panic word synced to Firestore Users/${user.uid}');
        await VoiceActivationFirestoreService().savePanicWord(word);
      }
    } catch (e) {
      debugPrint('Error syncing panic word to Firestore: $e');
    }
  }

  /// Get the current panic word
  Future<String?> getPanicWord() async {
    final prefs = await SharedPreferences.getInstance();
    final localWord = prefs.getString(_panicWordKey);

    final user = await _ensureAuthenticated();
    if (user != null) {
      try {
        final doc = await _firestore.collection('Users').doc(user.uid).get();
        // This fetches the panic word from the user's main profile document
        final data = doc.data();
        if (data != null && data.containsKey('panicWord')) {
          final cloudWord = data['panicWord'] as String;
          if (cloudWord != localWord) {
            await prefs.setString(_panicWordKey, cloudWord);
            return cloudWord;
          }
        }
      } catch (e) {
        debugPrint('Error fetching panic word from Firestore: $e');
      }
    }
    return localWord;
  }

  /// Set whether voice guardian is enabled
  Future<void> setVoiceGuardianEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceEnabledKey, enabled);
  }

  /// Check if voice guardian is enabled
  Future<bool> isVoiceGuardianEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_voiceEnabledKey) ?? true;
  }

  /// Set voice sensitivity (0.0 to 1.0)
  Future<void> setSensitivity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sensitivityKey, value);
  }

  /// Get voice sensitivity
  Future<double> getSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_sensitivityKey) ?? 0.5;
  }

  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticKey, enabled);
  }

  Future<bool> getHapticFeedbackEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticKey) ?? true;
  }

  Future<void> setVoiceFeedbackEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceFeedbackKey, enabled);
  }

  Future<bool> getVoiceFeedbackEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_voiceFeedbackKey) ?? false;
  }

  Future<void> setRecordAudioEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_recordAudioKey, enabled);
  }

  Future<bool> getRecordAudioEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_recordAudioKey) ?? true;
  }

  Future<void> setDiscreetModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_discreetModeKey, enabled);
  }

  Future<bool> getDiscreetModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_discreetModeKey) ?? false;
  }

  Future<void> setCustomSosMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customSosMessageKey, message);
  }

  Future<String> getCustomSosMessage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customSosMessageKey) ?? "SOS! I need help.";
  }

  Future<void> setSosCountdown(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sosCountdownKey, seconds);
  }

  Future<int> getSosCountdown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sosCountdownKey) ?? 5;
  }

  /// Initialize the background service for listening to triggers
  Future<void> initializeBackgroundService() async {
    // Background service functionality has been disabled.
    // Triggers now run in the foreground via main.dart
    debugPrint("Background Service is disabled. Triggers running in Foreground.");
  }

  /// Trigger emergency alert and send notifications to all contacts
  Future<void> activateEmergency() async {
    if (_isAlertActive) return;
    _isAlertActive = true;

    final user = await _ensureAuthenticated();
    if (user != null) {
      debugPrint('EmergencyAlertService: Activating emergency for UID: ${user.uid}');
      try {
        await _firestore.collection('Users').doc(user.uid).set({
          'isEmergencyActive': true,
          'lastAlertAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating emergency status in Firestore: $e');
      }
    }

    try {
      final contacts = await getEmergencyContacts();
      final phoneNumbers = contacts
          .map((c) => (c['phone'] ?? '').toString())
          .where((p) => p.isNotEmpty)
          .toList();
      
      if (phoneNumbers.isNotEmpty) {
        await _sendEmergencyNotification(phoneNumbers);
      }
    } catch (e) {
      debugPrint('Error activating emergency alert: $e');
    }
  }

  /// Send emergency notification to a phone number
  /// This integrates with Firebase Cloud Functions for SMS delivery
  Future<void> _sendEmergencyNotification(List<String> phoneNumbers) async {
    try {
      // Get current location
      String locationString = 'Unknown Location';
      try {
        // Faster retrieval using last known position first
        Position? position = await Geolocator.getLastKnownPosition();
        // If last known is unavailable or old, try a fresh high-accuracy position with a timeout
        position ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        
        locationString = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      } catch (e) {
        debugPrint('Error getting location for alert: $e');
      }

      // Send SMS to each contact via system SMS app (url_launcher)
      final customMsg = await getCustomSosMessage();
      final String messageBody = "$customMsg My location: $locationString";

      for (String phone in phoneNumbers) {
        try {
          final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(messageBody)}');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            debugPrint("Cannot launch SMS URI for $phone");
          }
        } catch (e) {
          debugPrint("Error sending SMS to $phone: $e");
        }
      }

      // Also log to Firebase (optional backup)
      await NotificationService.sendEmergencyNotification(
        phoneNumbers: phoneNumbers,
        userName: 'SafePath User',
        userLocation: locationString,
      );
      
      debugPrint('Emergency alert initiated for: $phoneNumbers at $locationString');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Stop emergency alert
  Future<void> deactivateEmergency() async {
    _isAlertActive = false;

    final user = await _ensureAuthenticated();
    if (user != null) {
      debugPrint('EmergencyAlertService: Deactivating emergency for UID: ${user.uid}');
      try {
        await _firestore.collection('Users').doc(user.uid).set({
          'isEmergencyActive': false,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error clearing emergency status in Firestore: $e');
      }
    }
  }

  /// Cancel alert
  Future<void> cancelAlert() async {
    await deactivateEmergency();
  }
}

/// Top-level function for background service execution
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure Flutter bindings are initialized
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for the background isolate
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase init error in background: $e');
  }

  final emergencyService = EmergencyAlertService();
  // Ensure background isolate is authenticated for Firestore triggers
  await emergencyService._ensureAuthenticated();

  final speech = SpeechToText();
  
  // --- Volume Button Trigger Setup ---
  int volumePressCount = 0;
  DateTime? lastVolumePress;
  
  // Listen to volume changes
  VolumeController().listener((volume) {
    final now = DateTime.now();
    
    // If the last press was within 1 second, increment count
    if (lastVolumePress != null && now.difference(lastVolumePress!) < const Duration(seconds: 1)) {
      volumePressCount++;
    } else {
      // Reset count if too much time passed
      volumePressCount = 1;
    }
    
    lastVolumePress = now;

    // Trigger if volume changed 3 times quickly (approx 3 presses)
    if (volumePressCount >= 3) {
      volumePressCount = 0;
      debugPrint("Volume Trigger Activated");
      emergencyService.activateEmergency();
    }
  });

  // --- Panic Word Trigger Setup ---
  bool isSpeechAvailable = await speech.initialize();
  String? panicWord = await emergencyService.getPanicWord();
  bool isVoiceGuardianEnabled = await emergencyService.isVoiceGuardianEnabled();
  double sensitivity = await emergencyService.getSensitivity();
  Timer? monitoringTimer;

  void startMonitoring(String word, bool enabled, double sense) {
    monitoringTimer?.cancel();
    if (!enabled) {
      speech.stop(); // Stop listening if disabled
      return;
    }
    
    void listen() {
      if (!speech.isListening) {
        try {
          speech.listen(
            // Sensitivity is 0.0-1.0, so 1.0 - sense gives the confidence threshold
            // If sense is 0.9 (high sensitivity), threshold is 0.1
            // If sense is 0.1 (low sensitivity), threshold is 0.9
            onResult: (result) {
              final triggerWords = word
                  .split(',')
                  .map((e) => e.trim().toLowerCase())
                  .where((w) => w.isNotEmpty);
              bool wordMatched = triggerWords.any(
                  (w) => result.recognizedWords.toLowerCase().contains(w));
              bool confidenceMet = result.hasConfidenceRating ? result.confidence >= (1.0 - sense) : true;

              if (wordMatched && confidenceMet) {
                debugPrint("Voice Trigger Activated: $word");
                emergencyService.activateEmergency();
              }
            },
            listenOptions: SpeechListenOptions(
              listenMode: ListenMode.dictation,
              partialResults: true,
              cancelOnError: false,
            ),
          );
        } catch (e) {
          debugPrint("Speech listen error: $e");
        }
      }
    }

    listen();
    monitoringTimer = Timer.periodic(const Duration(seconds: 2), (_) => listen());
  }

  if (isSpeechAvailable && (panicWord?.isNotEmpty ?? false) && isVoiceGuardianEnabled) {
    startMonitoring(panicWord!, isVoiceGuardianEnabled, sensitivity);
  }

  // Listen for updates to the panic word from the main app
  service.on('updateSettings').listen((event) async {
    final newPanicWord = await emergencyService.getPanicWord();
    final newVoiceGuardianEnabled = await emergencyService.isVoiceGuardianEnabled();
    final newSensitivity = await emergencyService.getSensitivity();

    panicWord = newPanicWord; // Keep local variable in sync
    isVoiceGuardianEnabled = newVoiceGuardianEnabled;
    sensitivity = newSensitivity;

    if (isSpeechAvailable && newPanicWord != null && newPanicWord.isNotEmpty && newVoiceGuardianEnabled) {
      if (speech.isListening) {
        await speech.stop();
      }
      startMonitoring(newPanicWord, newVoiceGuardianEnabled, newSensitivity);
    } else {
      monitoringTimer?.cancel();
    }
  });
}
