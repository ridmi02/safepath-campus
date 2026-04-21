import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'features/home/home_page.dart';
import 'features/home/splash_screen.dart';
import 'features/settings/data_sharing_policy_page.dart';
import 'features/settings/settings_page.dart';
import 'features/heatmap/campus_map_page.dart';
import 'features/login/login_screen.dart';
import 'features/login/forgot_password_screen.dart';
import 'features/profile/profile_page.dart';
import 'features/companion/companion_page.dart';
import 'theme/theme_provider.dart';
import 'features/registration/registration_provider.dart';
import 'features/registration/registration_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Root of the application with custom theme
  @override
  Widget build(BuildContext context) {
    // Brand colors
    const darkBackgroundColor = Color(0xFF0D1B2A); // #0D1B2A
    const darkCardColor = Color(0xFF1B263B); // #1B263B
    const lightBackgroundColor = Color(0xFFF5F7FB);
    const lightCardColor = Color(0xFFFFFFFF);

    // Palette requested by user
    const titleTextColor = Color(0xFFFFFFFF);
    const bodyTextColor = Color(0xFFC9D6DF);
    const disabledColorVal = Color(0xFF7F8C8D);
    const safeColor = Color(0xFF2ECC71);
    const warningColor = Color(0xFFF4D35E);
    const dangerColor = Color(0xFFE63946);
    const primaryIconColor = Color(0xFF3A86FF);

    final lightScheme = ColorScheme.fromSeed(seedColor: primaryIconColor)
        .copyWith(
          surface: lightCardColor,
          onSurface: const Color(0xFF1E293B),
          secondary: safeColor,
          tertiary: warningColor,
          error: dangerColor,
          brightness: Brightness.light,
        );

    // dark theme scheme: invert background and surfaces, keep palette
    final darkScheme =
        ColorScheme.fromSeed(
          seedColor: primaryIconColor,
          brightness: Brightness.dark,
        ).copyWith(
          surface: darkCardColor,
          onSurface: bodyTextColor,
          secondary: safeColor,
          tertiary: warningColor,
          error: dangerColor,
        );

    final lightTheme = ThemeData(
      colorScheme: lightScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: lightBackgroundColor,
      iconTheme: const IconThemeData(color: primaryIconColor),
      primaryIconTheme: const IconThemeData(color: primaryIconColor),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: Color(0xFF334155)),
      ),
      disabledColor: disabledColorVal,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF3A86FF),
        foregroundColor: titleTextColor,
      ),
    );

    final darkTheme = ThemeData(
      colorScheme: darkScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: darkBackgroundColor,
      iconTheme: const IconThemeData(color: primaryIconColor),
      primaryIconTheme: const IconThemeData(color: primaryIconColor),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: titleTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
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
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/register': (context) => const RegistrationScreen(),
            '/home': (context) => const MyHomePage(),
            '/campus_map': (context) => const CampusMapPage(),
            '/settings': (context) => const SettingsPage(),
            '/data_sharing_policy': (context) => const DataSharingPolicyPage(),
            '/profile': (context) => const ProfilePage(),
            '/companion': (context) => const CompanionPage(),
          },
        );
      },
    );
  }
}
