import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/core/utils/money.dart';
import 'package:tyf_mobile/features/transactions/screens/add_transaction_sheet.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: AddTransactionSheet())),
  );
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

  testWidgets(
    'expense form shows name, category, payment method and validates',
    (tester) async {
      await _pump(tester);
      expect(find.text('Paid with'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Investment'), findsOneWidget);

      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();
      expect(find.text('Give it a name'), findsOneWidget);
      expect(find.text('Pick a category'), findsOneWidget);
    },
  );

  testWidgets(
    'subcategory appears after picking a category with subcategories',
    (tester) async {
      await _pump(tester);
      expect(find.text('Subcategory (optional)'), findsNothing);
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(find.text('Subcategory (optional)'), findsOneWidget);
    },
  );

  testWidgets('switching types swaps the fields', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('Received via'), findsOneWidget);

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Paid with'), findsNothing);

    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();
    expect(find.text('Target amount'), findsOneWidget);
    expect(find.text('Already saved (optional)'), findsOneWidget);
  });

  testWidgets('transfer validates that From and To are picked', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '500');
    await tester.tap(find.text('Add transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Pick where the money comes from'), findsOneWidget);
  });

  testWidgets('recurring switch reveals the repeat interval', (tester) async {
    await _pump(tester);
    expect(find.text('Every'), findsNothing);
    await tester.ensureVisible(find.text('Recurring bill'));
    await tester.tap(find.text('Recurring bill'));
    await tester.pumpAndSettle();
    expect(find.text('Every'), findsOneWidget);
    expect(find.text('Repeats every month'), findsOneWidget);
  });

  testWidgets('sheet uses the theme accent, not a per-type colour', (
    tester,
  ) async {
    const accent = Color(0xFF7C5CE6);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: accent, primary: accent),
        ),
        home: const Scaffold(body: AddTransactionSheet()),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(button.style!.backgroundColor!.resolve({}), accent);
  });

  testWidgets('subcategory dropdown follows the category and resets', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Subcategory (optional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subcategory (optional)'));
    await tester.pumpAndSettle();
    expect(find.text('Tea/Coffee'), findsWidgets);
    await tester.tap(find.text('Milk').last);
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);

    await tester.ensureVisible(find.text('Travel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsNothing); // cleared on category change
    await tester.ensureVisible(find.text('Subcategory (optional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subcategory (optional)'));
    await tester.pumpAndSettle();
    expect(find.text('Petrol'), findsWidgets);
    expect(find.text('Tea/Coffee'), findsNothing);
  });
}
