import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../transactions/data/entry.dart';
import '../transactions/data/entry_repository.dart';
import '../transactions/data/transaction_options.dart';

/// The hidden "account" that balance corrections come from, so setting an
/// account's balance doesn't count as income or spending.
const adjustmentAccount = 'Balance adjustment';

/// Which account a payment method draws from (or pays into).
String accountFor(String? paymentMethod) => switch (paymentMethod) {
  'Cash' => 'Cash',
  'Credit card' => 'Credit card',
  'Wallet' => 'Wallet',
  _ => 'Bank account', // UPI, debit card, net banking, or not set
};

/// Each account's balance from entries dated up to [now]: income adds,
/// spending takes away (by payment method), transfers move money across.
Map<String, int> accountBalances(List<Entry> entries, DateTime now) {
  final end = DateTime(now.year, now.month, now.day + 1);
  final out = {for (final a in accounts) a: 0};
  void move(String? account, int paise) {
    if (account == null || account == adjustmentAccount) return;
    out[account] = (out[account] ?? 0) + paise;
  }

  for (final e in entries) {
    if (e.isDeleted || !e.date.isBefore(end)) continue;
    final d = e.data;
    switch (e.type) {
      case EntryType.income:
        move(accountFor(d.paymentMethod), d.amountPaise);
      case EntryType.expense:
        move(accountFor(d.paymentMethod), -d.amountPaise);
      case EntryType.transfer:
        move(d.fromAccount, -d.amountPaise);
        move(d.toAccount, d.amountPaise);
      case EntryType.goal:
        break;
    }
  }
  return out;
}

/// True if [e] touches [account] (for "See transactions").
bool entryTouches(Entry e, String account) => switch (e.type) {
  EntryType.income ||
  EntryType.expense => accountFor(e.data.paymentMethod) == account,
  EntryType.transfer =>
    e.data.fromAccount == account || e.data.toAccount == account,
  EntryType.goal => false,
};

final accountBalancesProvider = Provider<Map<String, int>>(
  (ref) => accountBalances(
    ref.watch(entriesProvider).value ?? const [],
    DateTime.now(),
  ),
);

/// A transfer from/to [adjustmentAccount] that makes [account] read
/// [target]. Null if it already does.
EntryDraft? adjustmentFor(
  String account,
  int current,
  int target,
  DateTime now,
) {
  final diff = target - current;
  if (diff == 0) return null;
  return EntryDraft(
    type: EntryType.transfer,
    amountPaise: diff.abs(),
    date: DateTime(now.year, now.month, now.day),
    name:
        'Balance set to ₹${(target / 100).toStringAsFixed(target % 100 == 0 ? 0 : 2)}',
    fromAccount: diff > 0 ? adjustmentAccount : account,
    toAccount: diff > 0 ? account : adjustmentAccount,
  );
}
