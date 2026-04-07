import 'package:safepath_campus/features/companion/companion_page.dart';
import 'dart:async'; // Added this import for the Timer class
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/app_theme.dart';
import 'services/notification_service.dart';
import 'features/home/home_page.dart';
import 'features/settings/data_sharing_policy_page.dart';
import 'features/settings/settings_page.dart';
import 'features/heatmap/campus_map_page.dart';
import 'services/voice_activation_page.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'services/emergency_alarm_service.dart';
import 'features/profile/profile_page.dart';
import 'features/emergency_contacts/emergency_contacts_page.dart';
import 'features/fake_call/fake_call_page.dart';
import 'screens/emergency_active_page.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Ensure user is signed in so we have a UID for Firestore
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    // Print this so you can find the correct document in your console link
    debugPrint('Current User UID: ${FirebaseAuth.instance.currentUser?.uid}');
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app' && e.code != 'admin-restricted-operation') {
      debugPrint('Firebase initialization failed: $e');
    }
  } catch (e) { 
    final s = e.toString();
    if (!s.contains('duplicate-app')) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notification service initialization failed: $e');
  }
  await dotenv.load(fileName: ".env");

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final EmergencyAlertService _emergencyService = EmergencyAlertService();
  final SpeechToText _speech = SpeechToText();
  int _volumePressCount = 0;
  DateTime? _lastVolumePress;
  Timer? _voiceTimer;

  @override
  void initState() {
    super.initState();
    _initForegroundTriggers();
  }

  void _initForegroundTriggers() async {
    // 1. Volume Button Trigger (Foreground)
    VolumeController().listener((volume) {
      final now = DateTime.now();
      if (_lastVolumePress != null && now.difference(_lastVolumePress!) < const Duration(seconds: 1)) {
        _volumePressCount++;
      } else {
        _volumePressCount = 1;
      }
      _lastVolumePress = now;

      if (_volumePressCount >= 3) {
        _volumePressCount = 0;
        _emergencyService.activateEmergency();
      }
    });

    // 2. Voice Activation Trigger (Foreground)
    bool isSpeechAvailable = await _speech.initialize();
    if (isSpeechAvailable) {
      _startForegroundVoiceMonitoring();
    }
  }

  void _startForegroundVoiceMonitoring() async {
    _voiceTimer?.cancel();
    final word = await _emergencyService.getPanicWord();
    final enabled = await _emergencyService.isVoiceGuardianEnabled();
    final sensitivity = await _emergencyService.getSensitivity();

    if (enabled && word != null && word.isNotEmpty) {
      _voiceTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (!_speech.isListening && mounted) {
          await _speech.listen(
            onResult: (result) {
              bool wordMatched = result.recognizedWords.toLowerCase().contains(word.toLowerCase());
              bool confidenceMet = result.hasConfidenceRating ? result.confidence >= (1.0 - sensitivity) : true;
              if (wordMatched && confidenceMet) {
                _emergencyService.activateEmergency();
              }
            },
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'SafePath Campus',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          home: const MyHomePage(),
          routes: {
            '/home': (context) => const MyHomePage(),
            '/campus_map': (context) => const CampusMapPage(),
            '/settings': (context) => const SettingsPage(),
            '/data_sharing_policy': (context) =>
                const DataSharingPolicyPage(),
            '/voice_activation': (context) => const VoiceActivationPage(),
            '/profile': (context) => const ProfilePage(),
            '/emergency_contacts': (context) => const EmergencyContactsPage(),
            '/companion': (context) => const CompanionPage(),
            '/fake_call': (context) => const FakeCallPage(),
            '/emergency_active': (context) {
              final args = ModalRoute.of(context)!.settings.arguments
                  as EmergencyActiveArgs;
              return EmergencyActivePage(args: args);
            },
          },
        );
      },
    );
  }
}