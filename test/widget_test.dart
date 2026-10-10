// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:money_management/main.dart';

void main() {
  testWidgets('App loads dashboard smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FinanceApp(startLoggedIn: true));

    // Verify that the dashboard screen is displayed by finding text from the first tab.
    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
