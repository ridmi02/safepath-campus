import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safepath_campus/features/companion/companion_page.dart';
import 'package:safepath_campus/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Companion notification entry', () {
    testWidgets('notification-style open lands on Companion chooser only', (
      tester,
    ) async {
      app.main();
      await tester.pump(const Duration(seconds: 3));

      app.appNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const CompanionPage()),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('The Companion'), findsWidgets);
      expect(find.text('I need a companion'), findsOneWidget);
      expect(find.text('I can help — open requests'), findsOneWidget);

      expect(find.text('Join with room code'), findsOneWidget);
      expect(find.text('Join video walk'), findsNothing);
      expect(find.text('Room code'), findsNothing);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('prefilled room code expands join panel without auto-joining', (
      tester,
    ) async {
      app.main();
      await tester.pump(const Duration(seconds: 3));

      app.appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const CompanionPage(
            initialRoomCode: 'ab12cd',
            autoJoinFromNotification: false,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Join with room code'), findsOneWidget);
      expect(find.text('Room code'), findsOneWidget);
      expect(find.text('Join video walk'), findsOneWidget);

      final roomCodeField = tester.widget<TextField>(find.byType(TextField));
      expect(roomCodeField.controller?.text, 'AB12CD');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
