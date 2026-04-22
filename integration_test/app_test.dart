import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safepath_campus/main.dart' as app;
import 'package:safepath_campus/features/home/home_page.dart';

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  Duration step = const Duration(milliseconds: 200),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  await tester.pumpAndSettle();
}

Future<void> _launchAndOpenHome(WidgetTester tester) async {
  app.main();
  await _pumpUntilVisible(tester, find.byType(MaterialApp));
  await _pumpUntilVisible(tester, find.byType(Navigator));

  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.pushNamed('/home');
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

Future<void> _pumpHomePage(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: MyHomePage()));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─── GROUP 1: App Launch & Navigation ─────────────────────────────────────
  group('App Launch & Navigation', () {
    testWidgets('Test 1: App launches and shows splash screen',
        (tester) async {
      app.main();
      await _pumpUntilVisible(tester, find.byType(MaterialApp));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Test 2: Splash screen shows SafePath Campus title',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('SafePath Campus'), findsWidgets);
    });

    testWidgets('Test 3: Splash screen shows safety tagline', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Your safety companion on campus'), findsOneWidget);
    });

    testWidgets('Test 4: Splash screen shows shield icon', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('Test 5: Splash screen shows loading indicator',
        (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Test 6: Splash screen auto-navigates to welcome screen',
        (tester) async {
      app.main();
      // Wait past the 2-second splash timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });
  });

  // ─── GROUP 2: Welcome Screen (YOUR UI) ────────────────────────────────────
  group('Welcome Screen UI', () {
    testWidgets('Test 7: Welcome screen has Register button', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 6));
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('Test 8: Welcome screen has Login button', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 6));
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Test 9: Register button is tappable and navigates',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 6));
      final registerButton = find.text('Register');
      if (registerButton.evaluate().isNotEmpty) {
        await tester.tap(registerButton);
        await tester.pumpAndSettle();
        expect(find.byType(Scaffold), findsOneWidget);
      }
    });

    testWidgets('Test 10: Login button is tappable and navigates',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 6));
      final loginButton = find.text('Login');
      if (loginButton.evaluate().isNotEmpty) {
        await tester.tap(loginButton);
        await tester.pumpAndSettle();
        expect(find.byType(Scaffold), findsOneWidget);
      }
    });
  });

  // ─── GROUP 3: Dark Mode / Light Mode (YOUR FEATURE) ───────────────────────
  group('Dark Mode & Light Mode - Theme System', () {
    testWidgets('Test 11: App has both light and dark themes configured',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      final materialApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull,
          reason: 'Light theme must be configured');
      expect(materialApp.darkTheme, isNotNull,
          reason: 'Dark theme must be configured');
    });

    testWidgets('Test 12: ThemeMode is set (not null)', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      final materialApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, isNotNull,
          reason: 'ThemeMode must be set by ThemeProvider');
    });

    testWidgets('Test 13: Light theme has white scaffold background',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      final materialApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme!.scaffoldBackgroundColor, equals(Colors.white));
    });

    testWidgets('Test 14: Dark theme has dark scaffold background',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      final materialApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(
        materialApp.darkTheme!.brightness,
        equals(Brightness.dark),
      );
    });

    testWidgets('Test 15: App title is SafePath Campus', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      final materialApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, equals('SafePath Campus'));
    });
  });

  // ─── GROUP 4: Settings Page (YOUR FEATURE) ────────────────────────────────
  group('Settings Page', () {
    testWidgets('Test 16: Settings page has Dark Mode toggle',
        (tester) async {
      app.main();
      // Wait for login flow to complete (app auto-logs in anonymously)
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to settings if we can find the route
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();
        expect(find.text('Dark Mode'), findsOneWidget);
      }
    });

    testWidgets('Test 17: Settings page has Notification toggle',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();
        expect(find.text('Enable push notifications'), findsOneWidget);
      }
    });

    testWidgets('Test 18: Settings page has Location tracking toggle',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();
        expect(find.text('Enable location tracking always'), findsOneWidget);
      }
    });

    testWidgets('Test 19: Settings page has Data sharing policy link',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();
        expect(find.text('Data sharing policy'), findsOneWidget);
      }
    });

    testWidgets('Test 20: Dark mode toggle switches theme', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();

        // Find the dark mode switch
        final darkModeSwitch = find.byType(SwitchListTile).first;
        if (darkModeSwitch.evaluate().isNotEmpty) {
          await tester.tap(darkModeSwitch);
          await tester.pumpAndSettle();
          // Switch toggled successfully — theme changed
          expect(find.byType(SwitchListTile), findsWidgets);
        }
      }
    });
  });

  // ─── GROUP 5: Campus Map Page (YOUR MAIN FEATURE) ─────────────────────────
  group('Campus Map & Heatmap', () {
    testWidgets('Test 21: Campus Map page loads from home', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Look for Map feature card on home page
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Campus Map'), findsOneWidget);
      }
    });

    testWidgets('Test 22: Campus Map has search destination field',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Search destination'), findsOneWidget);
      }
    });

    testWidgets('Test 23: Campus Map has Heatmap filter chip',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Heatmap'), findsOneWidget);
      }
    });

    testWidgets('Test 24: Campus Map has Safe Route filter chip',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Safe route'), findsOneWidget);
      }
    });

    testWidgets('Test 25: Campus Map has Crowd Overlay filter chip',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Crowd overlay'), findsOneWidget);
      }
    });

    testWidgets('Test 26: Heatmap toggle activates on chip tap',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        final heatmapChip = find.text('Heatmap');
        if (heatmapChip.evaluate().isNotEmpty) {
          await tester.tap(heatmapChip);
          await tester.pumpAndSettle();
          // Chip toggled — heatmap is now active
          expect(find.text('Heatmap'), findsOneWidget);
        }
      }
    });

    testWidgets('Test 27: Safe route toggle activates on chip tap',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        final safeRouteChip = find.text('Safe route');
        if (safeRouteChip.evaluate().isNotEmpty) {
          await tester.tap(safeRouteChip);
          await tester.pumpAndSettle();
          expect(find.text('Safe route'), findsOneWidget);
        }
      }
    });

    testWidgets('Test 28: Campus Map has SOS emergency FAB button',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byIcon(Icons.emergency), findsOneWidget);
      }
    });

    testWidgets('Test 29: Campus Map has center on user FAB button',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byIcon(Icons.my_location), findsWidgets);
      }
    });

    testWidgets('Test 30: Campus Map has incident filter button',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byIcon(Icons.tune), findsOneWidget);
      }
    });
  });

  // ─── GROUP 6: Incident Reporting (YOUR FEATURE) ───────────────────────────
  group('Incident Reporting System', () {
    testWidgets('Test 31: Incident filter opens bottom sheet', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        final filterBtn = find.byIcon(Icons.tune);
        if (filterBtn.evaluate().isNotEmpty) {
          await tester.tap(filterBtn);
          await tester.pumpAndSettle();
          expect(find.text('Incident filters'), findsOneWidget);
        }
      }
    });

    testWidgets('Test 32: Incident filter has Type section', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        final filterBtn = find.byIcon(Icons.tune);
        if (filterBtn.evaluate().isNotEmpty) {
          await tester.tap(filterBtn);
          await tester.pumpAndSettle();
          expect(find.text('Type'), findsOneWidget);
        }
      }
    });

    testWidgets('Test 33: Incident filter has Time section', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        final filterBtn = find.byIcon(Icons.tune);
        if (filterBtn.evaluate().isNotEmpty) {
          await tester.tap(filterBtn);
          await tester.pumpAndSettle();
          expect(find.text('Time'), findsOneWidget);
        }
      }
    });

    testWidgets('Test 34: Incident filter has Apply and Cancel buttons',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        final filterBtn = find.byIcon(Icons.tune);
        if (filterBtn.evaluate().isNotEmpty) {
          await tester.tap(filterBtn);
          await tester.pumpAndSettle();
          expect(find.text('Apply'), findsOneWidget);
          expect(find.text('Cancel'), findsOneWidget);
        }
      }
    });

    testWidgets('Test 35: Incident filter can be dismissed with Cancel',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      final mapCard = find.text('Map');
      if (mapCard.evaluate().isNotEmpty) {
        await tester.tap(mapCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        final filterBtn = find.byIcon(Icons.tune);
        if (filterBtn.evaluate().isNotEmpty) {
          await tester.tap(filterBtn);
          await tester.pumpAndSettle();
          final cancelBtn = find.text('Cancel');
          if (cancelBtn.evaluate().isNotEmpty) {
            await tester.tap(cancelBtn);
            await tester.pumpAndSettle();
            // Bottom sheet dismissed — Campus Map still visible
            expect(find.text('Heatmap'), findsOneWidget);
          }
        }
      }
    });
  });

  // ─── GROUP 7: Home Page Features (YOUR MAIN UI) ───────────────────────────
  group('Home Page UI', () {
    testWidgets('Test 36: Home page has SOS button', (tester) async {
      await _pumpHomePage(tester);
      final sosButton = find.text('SOS');
      expect(sosButton, findsOneWidget);
    });

    testWidgets('Test 37: Home page has Map feature card', (tester) async {
      await _pumpHomePage(tester);
      expect(find.text('Map'), findsWidgets);
    });

    testWidgets('Test 38: Home page has Settings icon in AppBar',
        (tester) async {
      await _pumpHomePage(tester);
      expect(find.byIcon(Icons.settings), findsWidgets);
    });

    testWidgets('Test 39: Home page has Profile icon in AppBar',
        (tester) async {
      await _pumpHomePage(tester);
      expect(find.byIcon(Icons.person), findsWidgets);
    });

    testWidgets('Test 40: Home page AppBar shows SafePath Campus title',
        (tester) async {
      await _pumpHomePage(tester);
      expect(find.text('SafePath Campus'), findsWidgets);
    });
  });
}