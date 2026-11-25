import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/accounts/account_balances.dart';
import 'package:tyf_mobile/features/history/history_screen.dart';
import 'package:tyf_mobile/features/transactions/data/entry.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

var _id = 0;
Entry entry(EntryDraft d) =>
    Entry(id: '${_id++}', data: d, createdAt: d.date, updatedAt: d.date);

EntryDraft flow(EntryType t, int rupees, String? method, {DateTime? on}) =>
    EntryDraft(
      type: t,
      amountPaise: rupees * 100,
      date: on ?? DateTime(2026, 11, 10),
      category: 'X',
      paymentMethod: method,
    );

EntryDraft move(int rupees, String from, String to) => EntryDraft(
  type: EntryType.transfer,
  amountPaise: rupees * 100,
  date: DateTime(2026, 11, 10),
  fromAccount: from,
  toAccount: to,
);

void main() {
  final now = DateTime(2026, 11, 25);

  test('payment methods map to accounts', () {
    expect(accountFor('UPI'), 'Bank account');
    expect(accountFor('Debit card'), 'Bank account');
    expect(accountFor('Net banking'), 'Bank account');
    expect(accountFor(null), 'Bank account');
    expect(accountFor('Cash'), 'Cash');
    expect(accountFor('Credit card'), 'Credit card');
    expect(accountFor('Wallet'), 'Wallet');
  });

  test('income, spending and transfers land in the right accounts', () {
    final b = accountBalances([
      entry(flow(EntryType.income, 50000, 'Net banking')),
      entry(flow(EntryType.expense, 300, 'UPI')),
      entry(flow(EntryType.expense, 200, 'Cash')),
      entry(flow(EntryType.expense, 1500, 'Credit card')),
      entry(move(2000, 'Bank account', 'Cash')),
      // Future-dated: not counted yet.
      entry(flow(EntryType.expense, 999, 'UPI', on: DateTime(2026, 12, 1))),
    ], now);
    expect(b['Bank account'], (50000 - 300 - 2000) * 100);
    expect(b['Cash'], (2000 - 200) * 100);
    expect(b['Credit card'], -1500 * 100);
    expect(b['Wallet'], 0);
  });

  test(
    'setting a balance adds a correction that is not income or spending',
    () {
      final start = [entry(flow(EntryType.expense, 200, 'Cash'))];
      final current = accountBalances(start, now)['Cash']!; // -₹200
      final fix = adjustmentFor('Cash', current, 150000, now)!; // ₹1,500
      expect(fix.type, EntryType.transfer);
      expect(fix.fromAccount, adjustmentAccount);
      expect(fix.amountPaise, 170000);
      final after = accountBalances([...start, entry(fix)], now);
      expect(after['Cash'], 150000);
      expect(entry(fix).balanceEffect, 0); // reports and totals unchanged
      expect(adjustmentFor('Cash', 150000, 150000, now), isNull);
    },
  );

  test('History can show just one account', () {
    final all = [
      entry(flow(EntryType.expense, 300, 'UPI')),
      entry(flow(EntryType.expense, 200, 'Cash')),
      entry(move(2000, 'Bank account', 'Cash')),
    ];
    final cash = groupByDay(
      all,
      const HistoryFilter(account: 'Cash'),
    ).expand((g) => g.$2).toList();
    expect(cash, hasLength(2)); // the cash spend and the transfer in
  });
}
