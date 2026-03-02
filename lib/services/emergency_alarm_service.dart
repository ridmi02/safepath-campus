import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';

class EmergencyAlertService {
  static bool _isAlertActive = false;
  static const String _contactsKey = 'emergency_contacts';
  static const String _panicWordKey = 'panic_word';
  
  bool get isAlertActive => _isAlertActive;

  /// Get list of emergency contacts
  Future<List<String>> getEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_contactsKey) ?? [];
  }

  /// Add emergency contact phone number
  Future<void> addEmergencyContact(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList(_contactsKey) ?? [];
    
    if (!contacts.contains(phoneNumber)) {
      contacts.add(phoneNumber);
      await prefs.setStringList(_contactsKey, contacts);
      
      // Subscribe to notifications for this contact
      await NotificationService.subscribeToEmergencyUpdates(phoneNumber);
    }
  }

  /// Remove emergency contact
  Future<void> removeEmergencyContact(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList(_contactsKey) ?? [];
    contacts.remove(phoneNumber);
    await prefs.setStringList(_contactsKey, contacts);
    
    // Unsubscribe from notifications for this contact
    await NotificationService.unsubscribeFromEmergencyUpdates(phoneNumber);
  }

  /// Set the custom panic word (e.g., "Help me")
  Future<void> setPanicWord(String word) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_panicWordKey, word);
  }

  /// Get the current panic word
  Future<String?> getPanicWord() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_panicWordKey);
  }

  /// Initialize the background service for listening to triggers
  Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        foregroundServiceNotificationId: 888,
        notificationChannelId: 'safepath_background_service',
        initialNotificationTitle: 'SafePath Active',
        initialNotificationContent: 'Listening for emergency triggers...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
      ),
    );

    await service.startService();
  }

  /// Trigger emergency alert and send notifications to all contacts
  Future<void> activateEmergency() async {
    if (_isAlertActive) return;
    _isAlertActive = true;

    try {
      final contacts = await getEmergencyContacts();
      
      // Send notification to each emergency contact
      for (final phoneNumber in contacts) {
        await _sendEmergencyNotification(phoneNumber);
      }
    } catch (e) {
      debugPrint('Error activating emergency alert: $e');
    }
  }

  /// Send emergency notification to a phone number
  /// This integrates with Firebase Cloud Functions for SMS delivery
  Future<void> _sendEmergencyNotification(String phoneNumber) async {
    try {
      // Use NotificationService to send emergency alert
      // The Cloud Function will handle SMS delivery via Twilio/AWS SNS
      await NotificationService.sendEmergencyNotification(
        phoneNumbers: [phoneNumber],
        userName: 'SafePath User',
        userLocation: 'Campus Location', // Could be enhanced with actual location from geolocator
      );
      
      debugPrint('Emergency alert initiated for: $phoneNumber');
    } catch (e) {
      debugPrint('Error sending notification to $phoneNumber: $e');
    }
  }

  /// Stop emergency alert
  Future<void> deactivateEmergency() async {
    _isAlertActive = false;
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
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error in background: $e');
  }

  final emergencyService = EmergencyAlertService();
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
  Timer? monitoringTimer;

  void startMonitoring(String word) {
    monitoringTimer?.cancel();
    
    void listen() {
      if (!speech.isListening) {
        try {
          speech.listen(
            onResult: (result) {
              if (result.recognizedWords.toLowerCase().contains(word.toLowerCase())) {
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

  if (isSpeechAvailable && panicWord != null && panicWord.isNotEmpty) {
    startMonitoring(panicWord);
  }

  // Listen for updates to the panic word from the main app
  service.on('updatePanicWord').listen((event) async {
    final newPanicWord = await emergencyService.getPanicWord();
    panicWord = newPanicWord; // Keep the outer variable in sync
    if (isSpeechAvailable && newPanicWord != null && newPanicWord.isNotEmpty) {
      // Restart listening with new word
      if (speech.isListening) {
        await speech.stop();
      }
      startMonitoring(newPanicWord);
    } else {
      monitoringTimer?.cancel();
    }
  });
}
