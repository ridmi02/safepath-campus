import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'features/login/login_screen.dart';
import 'features/registration/registration_provider.dart';
import 'features/registration/registration_screen.dart';
import 'services/notification_service.dart';
import 'features/home/splash_screen.dart';
import 'features/home/home_page.dart';
import 'features/settings/data_sharing_policy_page.dart';
import 'features/settings/settings_page.dart';
import 'features/heatmap/campus_map_page.dart';
import 'features/companion/companion_page.dart';
import 'features/profile/profile_page.dart';
import 'features/emergency_contacts/emergency_contacts_page.dart';
import 'features/fake_call/fake_call_page.dart';
import 'screens/emergency_active_page.dart';
import 'theme/theme_provider.dart';
import 'voice_activation_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notification service initialization failed: $e');
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Failed to load .env: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Brand colors
    const backgroundColor = Color(0xFF0D1B2A);
    const cardColor = Color(0xFF1B263B);
    const titleTextColor = Color(0xFFFFFFFF);
    const bodyTextColor = Color(0xFFC9D6DF);
    const disabledColorVal = Color(0xFF7F8C8D);
    const safeColor = Color(0xFF2ECC71);
    const warningColor = Color(0xFFF4D35E);
    const dangerColor = Color(0xFFE63946);
    const primaryIconColor = Color(0xFF3A86FF);

    final lightScheme = ColorScheme.fromSeed(seedColor: primaryIconColor)
        .copyWith(
      surface: cardColor,
      onSurface: bodyTextColor,
      secondary: safeColor,
      tertiary: warningColor,
      error: dangerColor,
      brightness: Brightness.light,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: primaryIconColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: cardColor,
      onSurface: bodyTextColor,
      secondary: safeColor,
      tertiary: warningColor,
      error: dangerColor,
    );

    final lightTheme = ThemeData(
      colorScheme: lightScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      iconTheme: const IconThemeData(color: primaryIconColor),
      primaryIconTheme: const IconThemeData(color: primaryIconColor),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
            color: titleTextColor,
            fontSize: 20,
            fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: bodyTextColor),
      ),
      disabledColor: disabledColorVal,
      appBarTheme: AppBarTheme(
        backgroundColor: lightScheme.primary,
        foregroundColor: titleTextColor,
      ),
    );

    final darkTheme = ThemeData(
      colorScheme: darkScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      iconTheme: const IconThemeData(color: primaryIconColor),
      primaryIconTheme: const IconThemeData(color: primaryIconColor),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
            color: titleTextColor,
            fontSize: 20,
            fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: bodyTextColor),
      ),
      disabledColor: disabledColorVal,
      appBarTheme: AppBarTheme(
        backgroundColor: darkScheme.primary,
        foregroundColor: titleTextColor,
      ),
    );

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'SafePath Campus',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          // WelcomeScreen is the entry point — handles Register/Login routing.
          // After login, auth flow routes to Admin or Student home.
          home: const WelcomeScreen(),
          routes: {
            LoginScreen.routeName: (context) => const LoginScreen(),
            '/register': (context) => const RegistrationScreen(),
            '/home': (context) => const MyHomePage(),
            '/splash': (context) => const SplashScreen(),
            '/campus_map': (context) => const CampusMapPage(),
            '/settings': (context) => const SettingsPage(),
            '/data_sharing_policy': (context) => const DataSharingPolicyPage(),
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

// ── WelcomeScreen ────────────────────────────────────────────────────────────
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'SafePath Campus',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your safety companion on campus',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),

              const Spacer(flex: 3),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text('Register'),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, LoginScreen.routeName);
                  },
                  child: const Text('Login'),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
