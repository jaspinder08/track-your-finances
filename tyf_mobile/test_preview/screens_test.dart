// Renders every main screen to PNG with real fonts, for UI review.
// Run: flutter test test_preview/screens_test.dart --update-goldens
// Not part of the normal test suite.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/app/app.dart';
import 'package:tyf_mobile/features/budgets/data/budget_repository.dart';
import 'package:tyf_mobile/features/categories/data/category_repository.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

Future<void> _loadFonts() async {
  final root = File(Platform.resolvedExecutable).parent.parent.parent.parent;
  final dir = Directory('${root.path}/artifacts/material_fonts');
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Light', 'Black']) {
    final f = File('${dir.path}/Roboto-$w.ttf');
    if (f.existsSync()) {
      roboto.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('${dir.path}/MaterialIcons-Regular.otf').readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

Future<void> _seed(InMemoryEntryRepository r, InMemoryBudgetRepository b) async {
  final now = DateTime.now();
  DateTime d(int day) => DateTime(now.year, now.month, day);
  Future<void> x(int rupees, String cat, int day, {String? name}) => r.add(
    EntryDraft(
      type: EntryType.expense,
      amountPaise: rupees * 100,
      date: d(day),
      category: cat,
      name: name,
      paymentMethod: 'UPI',
    ),
  );
  await r.add(
    EntryDraft(
      type: EntryType.income,
      amountPaise: 8500000,
      date: d(1),
      category: 'Salary',
      name: 'November salary',
    ),
  );
  await x(1500, 'Home', 3, name: 'Rent share');
  await x(420, 'Food', 5, name: 'Groceries');
  await x(260, 'Food', 8, name: 'Lunch');
  await x(1200, 'Travel', 9, name: 'Petrol');
  await x(649, 'Entertainment', 12, name: 'Movie night');
  await x(2300, 'Shopping', 15, name: 'Shoes');
  await x(899, 'Bills', 18, name: 'Electricity');
  await x(340, 'Food', 20, name: 'Dinner');
  await x(150, 'Travel', 22, name: 'Metro card');
  await x(75, 'Food', now.day, name: 'Tea');
  await r.add(
    EntryDraft(
      type: EntryType.transfer,
      amountPaise: 1000000,
      date: d(10),
      fromAccount: accounts.first,
      toAccount: accounts[1],
    ),
  );
  await r.add(
    EntryDraft(
      type: EntryType.goal,
      amountPaise: 15000000,
      date: DateTime(now.year + 1, 6, 1),
      name: 'Goa trip',
      savedSoFarPaise: 5500000,
    ),
  );
  await b.save(const CategoryBudget(category: 'Food', limitPaise: 150000));
  await b.save(const CategoryBudget(category: 'Travel', limitPaise: 120000));
  await b.save(const CategoryBudget(category: 'Shopping', limitPaise: 200000));
}

void main() {
  testWidgets('screens', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final entries = InMemoryEntryRepository();
    final budgets = InMemoryBudgetRepository();
    await _seed(entries, budgets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(entries),
          budgetRepositoryProvider.overrideWithValue(budgets),
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryRepository(),
          ),
        ],
        child: const TyfApp(),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/$name.png'),
      );
    }

    Future<void> tab(String label) async {
      await tester.tap(find.byTooltip(label).first);
      await tester.pumpAndSettle();
    }

    await shot('01_calendar');
    await tester.tap(find.text('${DateTime.now().day}').first);
    await shot('02_day_sheet');
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Insights'));
    await shot('02b_insights');
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    await tab('Budgets');
    await shot('03_budgets');
    await tab('Categories');
    await shot('04_categories');
    await tab('Reports');
    await shot('05_reports');
    await tab('Calendar');

    await tester.tap(find.byTooltip('Add transaction').first);
    await shot('06_add_form');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu').first);
    await shot('07_drawer');
    await tester.tap(find.text('Goals'));
    await shot('08_goals');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await shot('09_settings');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to back up'));
    await shot('10_sign_in');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tab('Budgets');
    await tester.tap(find.byTooltip('Add transaction').first);
    await shot('11_budget_sheet');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();

    await tab('Categories');
    await tester.tap(find.byTooltip('Add transaction').first);
    await shot('12_category_editor');
  });
}
