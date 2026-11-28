import '../transactions/data/transaction_options.dart';

/// A money movement read from a bank or UPI SMS.
class SmsTxn {
  const SmsTxn({
    required this.type,
    required this.amountPaise,
    required this.date,
    required this.paymentMethod,
    required this.body,
    this.party,
    this.accountTail,
  });

  /// Expense (debited/spent/paid) or income (credited/received).
  final EntryType type;
  final int amountPaise;
  final DateTime date;

  /// Who was paid or who paid, if the SMS says.
  final String? party;

  /// UPI, Debit card, Credit card or Net banking.
  final String paymentMethod;

  /// Last digits of the account or card, e.g. "1234".
  final String? accountTail;
  final String body;
}

final _amount = RegExp(
  r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
  caseSensitive: false,
);
final _debit = RegExp(
  r'\b(debited|spent|paid|sent|withdrawn|purchase|txn of|dr\b)',
  caseSensitive: false,
);
final _credit = RegExp(
  r'\b(credited|received|deposited|refund(?:ed)?|cr\b)',
  caseSensitive: false,
);

/// Promotional, OTP, reminder and failed-payment messages, not money
/// that actually moved.
final _ignore = RegExp(
  r'\b(otp|one time password|will be debited|is due|due on|due date|'
  r'request(?:ed)? (?:money|rs|inr)|collect request|failed|declined|'
  r'reversed|unsuccessful|minimum amount|min amt|offer|cashback upto|'
  r'pre-approved|loan of|apply now|win)\b',
  caseSensitive: false,
);
final _tail = RegExp(
  r'(?:a/?c|acct|account|card)[^\d]{0,12}(?:x+|\*+)?(\d{3,4})\b',
  caseSensitive: false,
);
final _party = <RegExp>[
  RegExp(
    r'\bto\s+(?:vpa\s+)?([A-Za-z0-9.@_\- ]{2,40}?)(?=\s+(?:on|ref|upi|via|from|for|avl|\.)|[.;,]|$)',
    caseSensitive: false,
  ),
  RegExp(
    r'\bat\s+([A-Za-z0-9.&_\- ]{2,40}?)(?=\s+(?:on|ref|txn|using|via|avl)|[.;,]|$)',
    caseSensitive: false,
  ),
  RegExp(
    r'\bfrom\s+(?:vpa\s+)?([A-Za-z0-9.@_\- ]{2,40}?)(?=\s+(?:on|ref|upi|via|to|avl)|[.;,]|$)',
    caseSensitive: false,
  ),
  RegExp(
    r'\binfo[:\-]\s*([A-Za-z0-9.@/_\- ]{2,40}?)(?=[.;,]|$)',
    caseSensitive: false,
  ),
];

/// Reads one SMS. Returns null if it isn't a completed debit or credit.
SmsTxn? parseBankSms(String body, DateTime date) {
  final text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (_ignore.hasMatch(text)) return null;
  final m = _amount.firstMatch(text);
  if (m == null) return null;
  final rupees = double.tryParse(m.group(1)!.replaceAll(',', ''));
  if (rupees == null || rupees <= 0) return null;

  final d = _debit.firstMatch(text)?.start;
  final c = _credit.firstMatch(text)?.start;
  if (d == null && c == null) return null;
  // Whichever word comes first decides ("debited … credited to X").
  final isDebit = c == null || (d != null && d < c);

  final lower = text.toLowerCase();
  final method = lower.contains('upi') || lower.contains('vpa')
      ? 'UPI'
      : lower.contains('credit card')
      ? 'Credit card'
      : lower.contains('card')
      ? 'Debit card'
      : lower.contains('atm')
      ? 'Cash'
      : 'Net banking';

  String? party;
  for (final r in _party) {
    final p = r.firstMatch(text)?.group(1)?.trim();
    if (p == null || p.isEmpty) continue;
    if (RegExp(
      r'^(?:your|a/?c|ac|acct|account|card)\b',
      caseSensitive: false,
    ).hasMatch(p)) {
      continue;
    }
    party = p;
    break;
  }

  return SmsTxn(
    type: isDebit ? EntryType.expense : EntryType.income,
    amountPaise: (rupees * 100).round(),
    date: date,
    party: party,
    paymentMethod: method,
    accountTail: _tail.firstMatch(text)?.group(1),
    body: text,
  );
}
