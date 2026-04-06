import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safepath_campus/main.dart';

void main() {
  testWidgets('SafePath home screen displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pump(); // Let the first frame render

    // Verify that the app renders without crashing
    expect(find.byType(Scaffold), findsOneWidget);

    // Verify home screen elements are present
    expect(find.text('SafePath'), findsOneWidget);
    expect(find.text('Campus Safety System'), findsOneWidget);
    expect(find.byIcon(Icons.emergency_share), findsOneWidget);
    expect(find.byIcon(Icons.record_voice_over), findsOneWidget);
  });
}
