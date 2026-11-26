import 'dart:async';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/money.dart';
import '../notifications/notifications.dart';
import '../transactions/data/transaction_options.dart';
import 'sms_parser.dart';

/// Identifies a detected transaction across scans and notifications.
String smsKey(SmsTxn t) =>
    '${t.type.name}|${t.amountPaise}|${t.date.millisecondsSinceEpoch}';

/// Keys of transactions the user has already seen on the Scan SMS screen
/// (so others can be labelled "New").
const _kSeen = 'sms_seen';

/// Keys already added to TYF or dismissed, so they're never offered again.
const _kDone = 'sms_done';

Future<Set<String>> loadSeen() async => {
  ...?(await SharedPreferences.getInstance()).getStringList(_kSeen),
};

Future<void> markSeen(Iterable<String> keys) async {
  final p = await SharedPreferences.getInstance();
  final all = {...?p.getStringList(_kSeen), ...keys};
  // Keep the list small: only recent keys matter.
  await p.setStringList(_kSeen, all.toList().reversed.take(800).toList());
}

Future<Set<String>> loadDone() async => {
  ...?(await SharedPreferences.getInstance()).getStringList(_kDone),
};

Future<void> markDone(Iterable<String> keys) async {
  final p = await SharedPreferences.getInstance();
  final all = {...?p.getStringList(_kDone), ...keys};
  await p.setStringList(_kDone, all.toList().reversed.take(800).toList());
}

/// Notification id for SMS alerts (one per transaction).
int _notifId(SmsTxn t) => smsKey(t).hashCode & 0x3fffffff | 0x40000000;

/// Payload on SMS notifications; tapping one opens Scan SMS.
const smsNotificationPayload = 'sms';

/// Handles one incoming message: if it's a bank debit/credit, notify.
Future<void> handleIncomingSms(String? body, int? dateMs) async {
  if (body == null) return;
  final date = dateMs == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(dateMs);
  final t = parseBankSms(body, date);
  if (t == null) return;
  if ((await loadDone()).contains(smsKey(t))) return;
  final isIncome = t.type == EntryType.income;
  final amount = '${isIncome ? '+' : '−'}${Money.format(t.amountPaise)}';
  final who = t.party == null
      ? ''
      : isIncome
      ? ' from ${t.party}'
      : ' to ${t.party}';
  await Notifications.instance.show(
    _notifId(t),
    isIncome ? 'Money received · $amount' : 'New expense · $amount',
    '${t.paymentMethod}$who · Tap to add it to TYF',
    payload: smsNotificationPayload,
  );
}

/// Runs when an SMS arrives while TYF is closed or in the background.
@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage m) async {
  WidgetsFlutterBinding.ensureInitialized();
  await handleIncomingSms(m.body, m.date);
}

bool _listening = false;

/// Starts listening for new SMS if TYF already has SMS access.
/// Call at launch and after the user grants access.
Future<void> startSmsWatch() async {
  if (_listening) return;
  if (!await Permission.sms.isGranted) return;
  _listening = true;
  Telephony.instance.listenIncomingSms(
    onNewMessage: (m) => unawaited(handleIncomingSms(m.body, m.date)),
    onBackgroundMessage: smsBackgroundHandler,
  );
}
