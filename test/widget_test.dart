// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:safepath_campus/main.dart';

void main() {
  testWidgets('Home page displays SafePath features', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Should show the app title and feature cards
    expect(find.text('SafePath Campus'), findsOneWidget);
    expect(find.text('Report Incident'), findsOneWidget);
    expect(find.text('Campus Map'), findsOneWidget);
    expect(find.text('Emergency Contacts'), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);
  });
}
