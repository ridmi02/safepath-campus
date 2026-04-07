import 'package:safepath_campus/features/companion/companion_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/app_theme.dart';
import 'services/notification_service.dart';
import 'features/home/home_page.dart';
import 'features/settings/data_sharing_policy_page.dart';
import 'features/settings/settings_page.dart';
import 'features/heatmap/campus_map_page.dart';
import 'package:safepath_campus/voice_activation_page.dart';
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
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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