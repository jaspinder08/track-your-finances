import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tyf_mobile/app/app.dart';
import 'package:tyf_mobile/app/theme/theme_controller.dart';
import 'package:tyf_mobile/features/account/data/account.dart';
import 'package:tyf_mobile/features/account/data/csv_export.dart';
import 'package:tyf_mobile/features/budgets/data/budget_repository.dart';
import 'package:tyf_mobile/features/categories/data/category_repository.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/entry_repository.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

AccountState _state({
  bool onboarded = true,
  DateTime? trial,
  String? prompted,
  String? email,
}) => AccountState(
  onboarded: onboarded,
  name: 'Jassi',
  trialStartedAt: trial,
  lastPromptDate: prompted,
  email: email,
);

void main() {
  setUpAll(() => initializeDateFormatting('en_IN'));
  final start = DateTime(2026, 11, 1, 10);

  group('gate', () {
    test('new user sees welcome', () {
      expect(_state(onboarded: false).gate(start), Gate.welcome);
    });

    test('daily prompt once per day during the trial', () {
      final s = _state(trial: start, prompted: '2026-11-01');
      expect(s.gate(start), Gate.app); // already prompted today
      expect(s.gate(DateTime(2026, 11, 2, 9)), Gate.dailyPrompt);
      expect(s.daysLeft(DateTime(2026, 11, 2)), 13);
    });

    test('locked from day 14; signed-in users are never gated', () {
      final s = _state(trial: start, prompted: '2026-11-14');
      expect(s.gate(DateTime(2026, 11, 14, 23)), Gate.app); // day 13
      expect(s.gate(DateTime(2026, 11, 15, 0, 1)), Gate.locked);
      expect(s.daysLeft(DateTime(2026, 11, 20)), 0);
      final signedIn = _state(trial: start, email: 'a@b.com');
      expect(signedIn.gate(DateTime(2027)), Gate.app);
    });
  });

  test(
    'notifier: onboarding starts the trial and skips today\'s prompt',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(accountProvider).gate(start), Gate.welcome);

      await c
          .read(accountProvider.notifier)
          .completeOnboarding(' Jassi ', now: start);
      final s = c.read(accountProvider);
      expect(s.name, 'Jassi');
      // Straight to the "sign in or guest" choice.
      expect(s.isFirstRun, isTrue);
      expect(s.gate(start), Gate.dailyPrompt);

      await c
          .read(accountProvider.notifier)
          .dismissForToday(now: start.add(const Duration(days: 1)));
      expect(
        c.read(accountProvider).gate(start.add(const Duration(days: 1))),
        Gate.app,
      );
    },
  );

  test('CSV export: header, sorted rows, quoting', () {
    Entry e(String id, DateTime d, String name) => Entry(
      id: id,
      createdAt: d,
      updatedAt: d,
      data: EntryDraft(
        type: EntryType.expense,
        amountPaise: 25050,
        date: d,
        name: name,
        category: 'Food',
      ),
    );
    final csv = entriesToCsv([
      e('2', DateTime(2026, 11, 5), 'Tea, "special"'),
      e('1', DateTime(2026, 11, 1), 'Lunch'),
    ]).split('\n');
    expect(csv[0], startsWith('Date,Type,Amount (INR),Name,Category'));
    expect(csv[1], startsWith('2026-11-01,Expense,250.50,Lunch,Food'));
    expect(csv[2], contains('"Tea, ""special"""'));
  });

  testWidgets('first open: welcome → name → guest choice → setup sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          entryRepositoryProvider.overrideWithValue(InMemoryEntryRepository()),
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
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us your name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Jassi');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Sign in, or continue as a guest.
    expect(find.text('Welcome, Jassi!'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.text('Continue as guest · 14-day free trial'));
    await tester.pumpAndSettle();

    // The app, with the setup sheet for a new (empty) account.
    expect(find.text('Mon'), findsOneWidget); // calendar
    expect(find.text('Let\'s set things up'), findsOneWidget);
    expect(prefs.getString('user_name'), 'Jassi');
  });

  testWidgets('after the trial: locked screen, no guest option', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'user_name': 'Jassi',
      'trial_started_at': DateTime.now()
          .subtract(const Duration(days: 20))
          .toIso8601String(),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          entryRepositoryProvider.overrideWithValue(InMemoryEntryRepository()),
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
    expect(find.text('Your free trial has ended'), findsOneWidget);
    expect(find.textContaining('Continue as guest'), findsNothing);
    expect(find.text('Export my data (CSV)'), findsOneWidget);

    // Without Firebase (tests), sign-in explains itself instead of faking.
    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Password'), findsOneWidget); // email-first
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('isn\'t available right now'), findsOneWidget);
  });
}
