import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/budgets/data/budget_repository.dart';
import 'package:tyf_mobile/features/categories/data/category_repository.dart';
import 'package:tyf_mobile/features/onboarding/setup_sheet.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';
import 'package:tyf_mobile/features/transactions/screens/add_transaction_sheet.dart';

void main() {
  testWidgets('setup: pick category, then expense opens with it selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryRepository(),
          ),
          entryRepositoryProvider.overrideWithValue(InMemoryEntryRepository()),
          budgetRepositoryProvider.overrideWithValue(
            InMemoryBudgetRepository(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSetupSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Let\'s set things up'), findsOneWidget);
    expect(find.text('Pick a category first.'), findsOneWidget);

    await tester.tap(find.text('🍔 Food'));
    await tester.pumpAndSettle();
    expect(find.text('Budget for 🍔 Food'), findsOneWidget);

    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    // The add form opens with Food already chosen.
    final form = find.byType(AddTransactionSheet);
    expect(form, findsOneWidget);
    expect(
      find.descendant(of: form, matching: find.textContaining('Food')),
      findsWidgets,
    );
  });
}
