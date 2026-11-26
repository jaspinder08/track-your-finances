import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/budgets/data/budget_repository.dart';
import 'package:tyf_mobile/features/notifications/notifications.dart';
import 'package:tyf_mobile/features/reports/pdf_report.dart';
import 'package:tyf_mobile/features/support/support.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('feedback email: address, subject and device details', () {
    final u = feedbackUri(FeedbackKind.bug, 'TYF 1.0.0 · Pixel 8');
    expect(u.scheme, 'mailto');
    expect(u.path, supportEmail);
    expect(u.queryParameters['subject'], 'TYF bug report');
    expect(u.queryParameters['body'], contains('Steps to reproduce'));
    expect(u.queryParameters['body'], contains('Pixel 8'));
    expect(u.query, isNot(contains('+'))); // spaces stay spaces in mail apps
  });

  test('budget alerts fire once per level per month', () {
    BudgetProgress p(int spent) => BudgetProgress(
      const CategoryBudget(category: 'Food', limitPaise: 10000),
      spent,
      null,
    );
    const m = '2026-11';
    expect(budgetAlertLevel(p(5000), {}, m), isNull);
    expect(budgetAlertLevel(p(8500), {}, m), 'near');
    expect(budgetAlertLevel(p(8500), {'$m|Food|near'}, m), isNull);
    expect(budgetAlertLevel(p(12000), {'$m|Food|near'}, m), 'over');
    expect(
      budgetAlertLevel(p(12000), {'$m|Food|near', '$m|Food|over'}, m),
      isNull,
    );
  });

  test('PDF report builds a real PDF', () async {
    final d = DateTime(2026, 11, 5);
    final bytes = await buildMonthPdf([
      Entry(
        id: '1',
        data: EntryDraft(
          type: EntryType.expense,
          amountPaise: 45000,
          date: d,
          name: 'Swiggy',
          category: 'Food',
          paymentMethod: 'UPI',
        ),
        createdAt: d,
        updatedAt: d,
      ),
    ], DateTime(2026, 11));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
