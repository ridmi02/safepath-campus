import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safepath_campus/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Companion mode flow', () {
    testWidgets('opens companion screen and join section', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 3));

      app.appNavigatorKey.currentState?.pushNamed('/companion');
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('The Companion'), findsWidgets);
      expect(find.text('I need a companion'), findsOneWidget);
      expect(find.text('I can help — open requests'), findsOneWidget);
      expect(find.text('Request virtual walk-home'), findsOneWidget);

      final joinTile = find.text('Join with room code');
      expect(joinTile, findsOneWidget);
      await tester.tap(joinTile);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Room code'), findsOneWidget);
      expect(find.text('Join video walk'), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
