import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safepath_campus/main.dart';

void main() {
  testWidgets('Splash screen displays with logo', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(); // Let the first frame render

    // Verify splash screen elements are present
    expect(find.text('SafePath'), findsWidgets);
    expect(find.text('Campus Safety'), findsOneWidget);
    expect(find.byIcon(Icons.security), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);

    // Pump through the 7-second delay for navigation
    // (in real app this would navigate to home, in test it catches the error)
    await tester.pumpAndSettle(const Duration(seconds: 7));
  });
}
