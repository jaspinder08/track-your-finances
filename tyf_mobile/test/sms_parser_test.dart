import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/features/sms/sms_parser.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

void main() {
  final when = DateTime(2026, 11, 20, 10, 30);

  test('UPI debit with payee', () {
    final t = parseBankSms(
      'Rs.450.00 debited from A/c XX1234 on 20-11-26 to VPA swiggy@icici '
      'UPI Ref 123456789. Not you? Call 1800',
      when,
    )!;
    expect(t.type, EntryType.expense);
    expect(t.amountPaise, 45000);
    expect(t.paymentMethod, 'UPI');
    expect(t.accountTail, '1234');
    expect(t.party, 'swiggy@icici');
  });

  test('card spend at a shop', () {
    final t = parseBankSms(
      'INR 2,300.50 spent on HDFC Bank Credit Card xx9876 at AMAZON '
      'on 2026-11-20. Avl Lmt: INR 50,000',
      when,
    )!;
    expect(t.amountPaise, 230050);
    expect(t.paymentMethod, 'Credit card');
    expect(t.party, 'AMAZON');
  });

  test('salary credit', () {
    final t = parseBankSms(
      'Your A/c XX5678 is credited with Rs 85,000.00 on 01-Nov-26 by NEFT '
      'from ACME PVT LTD. Avl Bal Rs 1,20,000',
      when,
    )!;
    expect(t.type, EntryType.income);
    expect(t.amountPaise, 8500000);
    expect(t.party, 'ACME PVT LTD');
  });

  test('ignores OTPs, reminders, failures and offers', () {
    for (final s in [
      '123456 is your OTP for txn of Rs 500 at FLIPKART. Do not share.',
      'Your EMI of Rs 4,500 is due on 05-12-2026.',
      'Rs 300 will be debited from your account for your subscription.',
      'Txn of Rs 999 failed. Amount will be reversed if debited.',
      'Get a pre-approved loan of Rs 5,00,000. Apply now!',
      'Hi, see you at 5pm',
    ]) {
      expect(parseBankSms(s, when), isNull, reason: s);
    }
  });
}
