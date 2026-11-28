import 'package:intl/intl.dart';

/// Money helpers. Amounts are stored as whole paise (minor units) in an int,
/// never as double, to avoid rounding errors. ₹12.50 is stored as 1250.
class Money {
  Money._();

  static final _full = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final _compact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  /// 520000 paise -> "₹5,200". Uses Indian grouping (₹1,00,000).
  static String format(int paise) => _full.format(paise / 100);

  /// 580000 paise -> "₹5.8K", 7500 -> "₹75", 200000 -> "₹2K".
  /// For tight spaces like calendar cells.
  static String compact(int paise) {
    if (paise.abs() < 100000) return format(paise); // under ₹1,000
    // "₹2.0K" -> "₹2K"
    return _compact
        .format(paise / 100)
        .replaceFirst(RegExp(r'\.0(?=[^\d]*$)'), '');
  }
}

/// Parses user input like "1,250.5" into paise (125050).
/// Returns null if it is not a valid positive amount with at most 2 decimals.
int? parsePaise(String input) {
  final text = input.replaceAll(',', '').trim();
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;
  final rupees = int.parse(match.group(1)!);
  final paise = int.parse((match.group(2) ?? '0').padRight(2, '0'));
  final total = rupees * 100 + paise;
  return total > 0 ? total : null;
}
