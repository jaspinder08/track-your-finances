import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tyf_mobile/app/app.dart';
import 'package:tyf_mobile/core/utils/money.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_IN'));

  testWidgets('shell shows balance, tabs switch, + opens add sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(InMemoryEntryRepository()),
        ],
        child: const TyfApp(),
      ),
    );
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

  testWidgets('adding an expense shows it on the calendar and balance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(InMemoryEntryRepository()),
        ],
        child: const TyfApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '250');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name, e.g. Groceries at DMart'),
      'Chai',
    );
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    expect(find.text('Add expense'), findsNothing); // sheet closed
    expect(find.text('-₹250'), findsOneWidget); // balance pill
    expect(find.text('−₹250'), findsOneWidget); // today's calendar cell

    await tester.tap(find.text('−₹250'));
    await tester.pumpAndSettle();
    expect(find.text('Chai'), findsOneWidget);
    expect(find.text('Food'), findsNothing);
  });

  test('Money formats paise as INR with Indian grouping', () {
    expect(Money.format(520000), '₹5,200');
    expect(Money.format(1000000000), '₹1,00,00,000');
  });
}
