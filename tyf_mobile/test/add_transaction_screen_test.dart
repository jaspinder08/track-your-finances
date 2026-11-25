import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/core/utils/money.dart';
import 'package:tyf_mobile/features/categories/data/category_repository.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';
import 'package:tyf_mobile/features/transactions/screens/add_transaction_screen.dart';

Future<InMemoryEntryRepository> _pump(
  WidgetTester tester, {
  ThemeData? theme,
  EntryType initialType = EntryType.expense,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final entries = InMemoryEntryRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryRepository(),
        ),
        entryRepositoryProvider.overrideWithValue(entries),
      ],
      child: MaterialApp(
        theme: theme,
        home: AddTransactionScreen(initialType: initialType),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return entries;
}

Finder get _amount => find.byType(TextField).first;

Future<void> _pickCategory(WidgetTester tester, String name) async {
  await tester.tap(find.text('Category').first);
  await tester.pumpAndSettle();
  expect(find.text('Choose a category'), findsOneWidget);
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  group('parsePaise', () {
    test('valid inputs', () {
      expect(parsePaise('250'), 25000);
      expect(parsePaise('99.5'), 9950);
      expect(parsePaise('1,250.05'), 125005);
    });
    test('invalid inputs', () {
      for (final bad in ['', '0', 'abc', '1.234', '-5']) {
        expect(parsePaise(bad), isNull, reason: bad);
      }
    });
  });

  testWidgets('page layout and validation', (tester) async {
    await _pump(tester);
    expect(find.text('Add a transaction'), findsOneWidget);
    expect(find.text('Amount spent'), findsOneWidget);
    expect(find.text('Paid to'), findsOneWidget);
    expect(find.text('Paid with'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount, e.g. 250 or 99.50'), findsOneWidget);
    expect(find.text('Give it a name'), findsOneWidget);
    expect(find.text('Pick a category'), findsOneWidget);
  });

  testWidgets('category picker sheet sets the category', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Category').first);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Investment'), findsOneWidget);
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a category'), findsNothing);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Subcategory (optional)'), findsOneWidget);
  });

  testWidgets('subcategory dropdown follows the category and resets', (
    tester,
  ) async {
    await _pump(tester);
    await _pickCategory(tester, 'Food');
    await tester.tap(find.text('Subcategory (optional)'));
    await tester.pumpAndSettle();
    expect(find.text('Tea/Coffee'), findsWidgets);
    await tester.tap(find.text('Milk').last);
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);

    await _pickCategory(tester, 'Travel');
    expect(find.text('Milk'), findsNothing); // cleared on category change
    await tester.tap(find.text('Subcategory (optional)'));
    await tester.pumpAndSettle();
    expect(find.text('Petrol'), findsWidgets);
    expect(find.text('Tea/Coffee'), findsNothing);
  });

  testWidgets('switching types swaps the fields', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('Amount received'), findsOneWidget);
    expect(find.text('Received from'), findsOneWidget);
    expect(find.text('Received via'), findsOneWidget);

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Amount to move'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Category'), findsNothing);

    // Goals are created on the Goals page, not here.
    expect(find.text('Goal'), findsNothing);
  });

  testWidgets('goal mode: own title, no type pills', (tester) async {
    await _pump(tester, initialType: EntryType.goal);
    expect(find.text('New goal'), findsOneWidget);
    expect(find.text('Expense'), findsNothing);
    expect(find.text('Target amount'), findsOneWidget);
    expect(find.text('Goal name'), findsOneWidget);
    expect(find.text('Target date'), findsOneWidget);
    expect(find.text('Already saved (optional)'), findsOneWidget);
  });

  testWidgets('transfer validates that From and To are picked', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    await tester.enterText(_amount, '500');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Pick where the money comes from'), findsOneWidget);
  });

  testWidgets('repeat switch reveals the interval', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Every'), findsOneWidget);
    expect(find.textContaining('repeats every month'), findsOneWidget);
  });

  testWidgets('more options reveals notes', (tester) async {
    await _pump(tester);
    expect(find.text('Notes'), findsNothing);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget);
  });

  testWidgets('save & add another saves and clears the form', (tester) async {
    final entries = await _pump(tester);
    await tester.enterText(_amount, '250');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name or place'),
      'Chai',
    );
    await _pickCategory(tester, 'Food');
    await tester.tap(find.text('Save & add another'));
    await tester.pumpAndSettle();

    final saved = await entries.all();
    expect(saved.single.data.name, 'Chai');
    expect(saved.single.amountPaise, 25000);
    expect(saved.single.data.category, 'Food');
    expect(find.text('Add a transaction'), findsOneWidget); // still open
    expect(find.text('Chai'), findsNothing); // cleared
  });

  testWidgets('page uses the theme accent, not a per-type colour', (
    tester,
  ) async {
    const accent = Color(0xFF7C5CE6);
    await _pump(
      tester,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: accent, primary: accent),
      ),
    );
    Color? saveBg() => tester
        .widget<FilledButton>(find.byWidgetPredicate((w) => w is FilledButton))
        .style
        ?.backgroundColor
        ?.resolve({});
    // Theme-driven: either the explicit style or the theme's primary.
    expect(saveBg() ?? accent, accent);
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(saveBg() ?? accent, accent);
  });
}
