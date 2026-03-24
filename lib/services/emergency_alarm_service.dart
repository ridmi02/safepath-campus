import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';
import 'notification_service.dart';
import '../firebase_options.dart';

class EmergencyAlertService {
  static bool _isAlertActive = false;
  static const String _contactsKey = 'emergency_contacts';
  static const String _panicWordKey = 'panic_word';
  
  bool get isAlertActive => _isAlertActive;

  /// Get list of emergency contacts
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_contactsKey) ?? [];
    
    return rawList.map((item) {
      try {
        return jsonDecode(item) as Map<String, dynamic>;
      } catch (e) {
        // Handle legacy simple phone number strings
        return {'phone': item, 'name': 'Unknown', 'relation': 'Emergency Contact'};
      }
    }).toList();
  }

  /// Add emergency contact phone number
  Future<void> addEmergencyContact(String name, String phone, String relation) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList(_contactsKey) ?? [];
    
    // Check for duplicates based on phone
    bool exists = contacts.any((item) {
      try {
        final map = jsonDecode(item);
        return map['phone'] == phone;
      } catch (e) {
        return item == phone;
      }
    });

    if (!exists) {
      final newContact = {
        'name': name,
        'phone': phone,
        'relation': relation,
        'addedAt': DateTime.now().toIso8601String(),
      };
      contacts.add(jsonEncode(newContact));
      await prefs.setStringList(_contactsKey, contacts);
      
      // Subscribe to notifications for this contact
      await NotificationService.subscribeToEmergencyUpdates(phone);
    }
  }

  /// Remove emergency contact
  Future<void> removeEmergencyContact(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList(_contactsKey) ?? [];
    
    contacts.removeWhere((item) {
      try {
        final map = jsonDecode(item);
        return map['phone'] == phoneNumber;
      } catch (e) {
        return item == phoneNumber;
      }
    });
    
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
      final phoneNumbers = contacts.map((c) => c['phone'] as String).toList();
      
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
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
        );
        locationString = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      } catch (e) {
        debugPrint('Error getting location for alert: $e');
      }

      // Send Direct SMS to each contact
      String messageBody = "SOS! I need help. My location: $locationString";
      
      for (String phone in phoneNumbers) {
        final Telephony telephony = Telephony.instance;
        try {
          await telephony.sendSms(
            to: phone,
            message: messageBody,
            statusListener: (SendStatus status) => debugPrint("SMS status for $phone: $status"),
          );
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
