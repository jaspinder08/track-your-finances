import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tyf_mobile/app/app.dart';
import 'package:tyf_mobile/core/utils/money.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_IN'));

  testWidgets('shell shows balance, tabs switch, + opens add sheet', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TyfApp()));
    await tester.pumpAndSettle();

    expect(find.text('₹0'), findsWidgets);
    expect(find.text('Mon'), findsOneWidget);

    await tester.tap(find.byTooltip('Budgets').first);
    await tester.pumpAndSettle();
    expect(find.text('No budgets yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
  });

  test('Money formats paise as INR with Indian grouping', () {
    expect(Money.format(520000), '₹5,200');
    expect(Money.format(1000000000), '₹1,00,00,000');
  });
}
