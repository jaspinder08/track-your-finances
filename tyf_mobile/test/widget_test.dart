import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tyf_mobile/app/app.dart';
import 'package:tyf_mobile/core/utils/money.dart';
import 'package:tyf_mobile/features/budgets/data/budget_repository.dart';
import 'package:tyf_mobile/features/categories/data/category_repository.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_IN'));

  testWidgets('shell shows balance, tabs switch, + opens add sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(InMemoryEntryRepository()),
          budgetRepositoryProvider.overrideWithValue(
            InMemoryBudgetRepository(),
          ),
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

    // On other tabs + adds an entry.
    await tester.tap(find.byTooltip('Calendar').first);
    await tester.pumpAndSettle();
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
          budgetRepositoryProvider.overrideWithValue(
            InMemoryBudgetRepository(),
          ),
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

    // Tap the entry to edit it: the sheet opens pre-filled.
    await tester.tap(find.text('Chai'));
    await tester.pumpAndSettle();
    expect(find.text('Edit expense'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '250'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '250'), '300');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Chai'),
      'Chai & samosa',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Chai & samosa'), findsOneWidget); // day list updated
    expect(find.text('−₹300'), findsWidgets); // list, net, cell
    expect(find.text('-₹300'), findsOneWidget); // balance updated
  });

  testWidgets('+ on Budgets sets a budget and the card tracks spending', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final entries = InMemoryEntryRepository();
    await entries.add(
      EntryDraft(
        type: EntryType.expense,
        amountPaise: 450000,
        date: DateTime.now(),
        name: 'Groceries',
        category: 'Food',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(entries),
          budgetRepositoryProvider.overrideWithValue(
            InMemoryBudgetRepository(),
          ),
        ],
        child: const TyfApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Budgets').first);
    await tester.pumpAndSettle();
    expect(find.text('No budgets yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    expect(find.text('New budget'), findsOneWidget);

    await tester.tap(find.text('Save')); // nothing picked yet
    await tester.pumpAndSettle();
    expect(find.text('Pick a category'), findsOneWidget);

    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount per month'),
      '5000',
    );
    await tester.pumpAndSettle();
    expect(find.text('This month so far'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New budget'), findsNothing);
    expect(find.text('Category budgets'), findsOneWidget);
    expect(find.text('₹4,500 of ₹5,000'), findsOneWidget);
    expect(find.text('Almost there'), findsOneWidget); // 90% used
    expect(find.text('₹500'), findsWidgets); // left

    // Tap the card to edit it.
    await tester.tap(find.text('₹4,500 of ₹5,000'));
    await tester.pumpAndSettle();
    expect(find.text('Edit budget'), findsOneWidget);
    expect(find.text('Remove budget'), findsOneWidget);
  });

  testWidgets('Reports shows summary, categories and drill-down', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final entries = InMemoryEntryRepository();
    final today = DateTime.now();
    await entries.add(
      EntryDraft(
        type: EntryType.income,
        amountPaise: 4000000,
        date: today,
        category: 'Salary',
      ),
    );
    await entries.add(
      EntryDraft(
        type: EntryType.expense,
        amountPaise: 1000000,
        date: today,
        name: 'Rent',
        category: 'Home',
        paymentMethod: 'UPI',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(entries),
          budgetRepositoryProvider.overrideWithValue(
            InMemoryBudgetRepository(),
          ),
        ],
        child: const TyfApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reports').first);
    await tester.pumpAndSettle();

    expect(find.text('Saved this month'), findsOneWidget);
    expect(find.text('₹30,000'), findsWidgets);
    expect(find.text('75% of income'), findsOneWidget);
    expect(find.text('Where it went'), findsOneWidget);

    await tester.tap(find.byTooltip('See Home entries'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsWidgets);
  });

  testWidgets('Goals: switch, add savings, reach the goal', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final entries = InMemoryEntryRepository();
    final now = DateTime.now();
    await entries.add(
      EntryDraft(
        type: EntryType.goal,
        amountPaise: 1000000,
        date: DateTime(now.year + 1, now.month),
        name: 'Trip to Goa',
        savedSoFarPaise: 400000,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(entries),
          budgetRepositoryProvider.overrideWithValue(
            InMemoryBudgetRepository(),
          ),
        ],
        child: const TyfApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Budgets').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();

    expect(find.text('Trip to Goa'), findsOneWidget);
    expect(find.text('₹4,000 of ₹10,000'), findsOneWidget);
    expect(find.text('40%'), findsWidgets);

    // + on the Goals view starts a new goal.
    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    expect(find.text('New goal'), findsOneWidget);
    await tester.tapAt(const Offset(200, 40)); // dismiss
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trip to Goa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add savings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All ₹6,000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Goal reached'), findsOneWidget);
    expect(find.text('🎉 Trip to Goa reached!'), findsOneWidget);
  });

  testWidgets('Categories: add, rename (entries follow), use in add sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final entries = InMemoryEntryRepository();
    await entries.add(
      EntryDraft(
        type: EntryType.expense,
        amountPaise: 30000,
        date: DateTime.now(),
        name: 'Vet visit',
        category: 'Health',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(entries),
          budgetRepositoryProvider.overrideWithValue(
            InMemoryBudgetRepository(),
          ),
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryRepository(),
          ),
        ],
        child: const TyfApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Categories').first);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    final list = find.byType(Scrollable).last;

    // Rename Health -> Wellness: the existing entry moves with it.
    await tester.scrollUntilVisible(find.text('Health'), 200, scrollable: list);
    expect(find.text('1 entry this month'), findsOneWidget);
    await tester.tap(find.text('Health'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Health'),
      'Wellness',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await entries.all()).single.data.category, 'Wellness');
    expect(find.text('Wellness'), findsOneWidget);

    // + on Categories adds a new one; duplicates are refused.
    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Food');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('You already have "Food"'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Pets');
    await tester.tap(find.text('🐶'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Add a subcategory'),
      'Vet',
    );
    await tester.tap(find.byTooltip('Add subcategory'));
    await tester.pumpAndSettle();
    expect(find.text('Vet'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsNothing); // saved and closed
    await tester.scrollUntilVisible(find.text('Pets'), 300, scrollable: list);
    expect(find.text('Pets'), findsOneWidget);

    // The add sheet now offers the new category.
    await tester.tap(find.byTooltip('Calendar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pets'));
    expect(find.text('Pets'), findsOneWidget);
    expect(find.text('Wellness'), findsOneWidget);
  });

  test('Money formats paise as INR with Indian grouping', () {
    expect(Money.format(520000), '₹5,200');
    expect(Money.format(1000000000), '₹1,00,00,000');
  });
}
