// Basic Flutter widget test for WeSafe app.
import 'package:flutter_test/flutter_test.dart';
import 'package:womensafteyhackfair/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that the app mounts successfully
    expect(find.byType(MyApp), findsOneWidget);
  });
}
