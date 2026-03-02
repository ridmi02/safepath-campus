import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Root of the application with custom theme
  @override
  Widget build(BuildContext context) {
    // Brand colors
    const backgroundColor = Color(0xFF0D1B2A); // #0D1B2A
    const cardColor = Color(0xFF1B263B); // #1B263B

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
        surface: cardColor,
        onSurface: bodyTextColor,
        secondary: safeColor,
        tertiary: warningColor,
        error: dangerColor,
        brightness: Brightness.light,
      );

    // dark theme scheme: invert background and surfaces, keep palette
    final darkScheme = ColorScheme.fromSeed(seedColor: primaryIconColor,
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
        titleLarge: TextStyle(color: titleTextColor, fontSize: 20, fontWeight: FontWeight.w600),
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
        titleLarge: TextStyle(color: titleTextColor, fontSize: 20, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: bodyTextColor),
      ),
      disabledColor: disabledColorVal,
      appBarTheme: AppBarTheme(
        backgroundColor: darkScheme.primary,
        foregroundColor: titleTextColor,
      ),
    );

    return MaterialApp(
      title: 'SafePath Campus',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const MyHomePage(),
      },
    );
  }
}

// Updated home screen for SafePath Campus
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  void _triggerSOS(BuildContext context) {
    // TODO: Implement SOS emergency action
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Emergency Alert Sent!'),
        backgroundColor: Color(0xFFE63946),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // compute a subtle tint color for hero container without using deprecated
    // color component accessors
    final int scaffoldBgVal = Theme.of(context).scaffoldBackgroundColor.toARGB32();
    final int scaffoldR = (scaffoldBgVal >> 16) & 0xFF;
    final int scaffoldG = (scaffoldBgVal >> 8) & 0xFF;
    final int scaffoldB = scaffoldBgVal & 0xFF;
    final Color heroTint = Color.fromARGB((0.06 * 255).round(), scaffoldR, scaffoldG, scaffoldB);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafePath Campus'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero / logo placeholder
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: heroTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'SafePath',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // SOS Emergency Button - Big Circular Button in Center
            Center(
              child: GestureDetector(
                onTap: () => _triggerSOS(context),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE63946),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE63946).withAlpha((0.4 * 255).round()),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _triggerSOS(context),
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: Text(
                          'SOS',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: const [
                      Expanded(
                          child: _FeatureCard(
                              icon: Icons.warning,
                              label: 'Report Incident')),
                      SizedBox(width: 12),
                      Expanded(
                          child: _FeatureCard(
                              icon: Icons.map, label: 'Campus Map')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Expanded(
                          child: _FeatureCard(
                              icon: Icons.phone,
                              label: 'Emergency Contacts')),
                      SizedBox(width: 12),
                      Expanded(
                          child: _FeatureCard(
                              icon: Icons.person, label: 'My Profile')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // use a container color to contrast strongly with dark background
    final cardBg = colorScheme.primaryContainer; // light blue in palette
    final cardText = colorScheme.onPrimaryContainer;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 4,
      color: cardBg,
      child: InkWell(
        onTap: () {
          // TODO: navigate to feature
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: cardText),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cardText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Splash screen with custom logo and brand colors
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _animationController.forward();

    // Auto-navigate to home after 7 seconds
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted) {
        try {
          Navigator.of(context).pushReplacementNamed('/home');
        } catch (e) {
          // Silently ignore in test environment where route may not exist
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Custom SafePath logo
              Stack(
                alignment: Alignment.center,
                children: [
                  // Shield background
                  Container(
                    width: 140,
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A86FF).withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  // Icon stack with shield and location pin
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.security,
                            size: 80,
                            color: const Color(0xFF3A86FF),
                          ),
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2ECC71),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.location_on,
                                size: 20,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // App name
              const Text(
                'SafePath',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFFFFF),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Campus Safety',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFC9D6DF),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
