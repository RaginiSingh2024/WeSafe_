import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womensafteyhackfair/Dashboard/LearningHub/SafetyLearningHub.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SafetyLearningHubScreen mounts and renders elements', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SafetyLearningHubScreen(),
      ),
    ));

    // Check title presence
    expect(find.text('Safety Learning Hub'), findsOneWidget);
    expect(find.text('PREPARE & PREVENT'), findsOneWidget);

    // Check default video list contains curated videos
    expect(find.text('Self Defense Training Video 1'), findsOneWidget);
    expect(find.text('Self Defense Training Video 2'), findsOneWidget);
    expect(find.text('Travel Safety Guide 1'), findsOneWidget);
    expect(find.text('Travel Safety Guide 2'), findsOneWidget);
    expect(find.text("Don't Panic in Emergency Situations"), findsOneWidget);
  });

  testWidgets('SafetyLearningHubScreen search filters list dynamically', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SafetyLearningHubScreen(),
      ),
    ));

    // Type "Panic" in search bar
    await tester.enterText(find.byType(TextField), 'Panic');
    await tester.pumpAndSettle();

    // Should only match the "Don't Panic in Emergency Situations" video
    expect(find.text("Don't Panic in Emergency Situations"), findsOneWidget);
    expect(find.text('Self Defense Training Video 1'), findsNothing);
    expect(find.text('Travel Safety Guide 1'), findsNothing);
  });
}
