import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:money_management/main.dart';
import 'package:money_management/providers/transaction_provider.dart';

void main() {
  testWidgets('FinBlend smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(),
        child: const FinBlendApp(),
      ),
    );

    expect(find.byType(FinBlendApp), findsOneWidget);
  });
}