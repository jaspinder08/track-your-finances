import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../app/theme/theme_controller.dart';
import '../budgets/data/budget_repository.dart';

/// Local notifications (daily reminder, budget alerts) plus FCM pushes.
/// Everything is scheduled on the phone; FCM is for messages sent from
/// the Firebase console.
class Notifications {
  Notifications._();
  static final instance = Notifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _reminderId = 1;
  static const _channel = AndroidNotificationDetails(
    'tyf_general',
    'Reminders and alerts',
    channelDescription: 'Daily reminder, budget alerts and announcements',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(android: _channel);

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p != null) taps.add(p);
      },
    );
    _ready = true;
  }

  /// Asks for permission (Android 13+). True if allowed.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? true;
  }

  Future<void> show(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
    );
  }

  /// Payloads of tapped notifications (the app routes on them).
  final taps = StreamController<String>.broadcast();

  /// The payload of the notification that launched the app, if any.
  Future<String?> launchPayload() async {
    await init();
    final d = await _plugin.getNotificationAppLaunchDetails();
    return d?.didNotificationLaunchApp == true
        ? d!.notificationResponse?.payload
        : null;
  }

  /// "Did you note today's spending?" every day at [time].
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _reminderId,
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Did you note today\'s spending?',
      body: 'Take 10 seconds to add what you spent today in TYF.',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    await init();
    await _plugin.cancel(id: _reminderId);
  }

  /// FCM: permission, token saved to the user's doc, and foreground
  /// messages shown as local notifications.
  Future<void> initPush() async {
    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission();
      // The classic token is what the Firebase console's "Send test
      // message" and Cloud Messaging campaigns target.
      // ignore: deprecated_member_use
      await _saveToken(await fcm.getToken());
      // ignore: deprecated_member_use
      fcm.onTokenRefresh.listen(_saveToken);
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) {
          show(m.hashCode, n.title ?? 'TYF', n.body ?? '');
        }
      });
    } catch (_) {
      // Firebase unavailable (offline first run, tests): local still works.
    }
  }

  Future<void> _saveToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (token == null || user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }
}

/// Saved notification choices.
@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.dailyReminder = false,
    this.reminderTime = const TimeOfDay(hour: 21, minute: 0),
    this.budgetAlerts = false,
  });
  final bool dailyReminder;
  final TimeOfDay reminderTime;
  final bool budgetAlerts;

  NotificationPrefs copyWith({
    bool? dailyReminder,
    TimeOfDay? reminderTime,
    bool? budgetAlerts,
  }) => NotificationPrefs(
    dailyReminder: dailyReminder ?? this.dailyReminder,
    reminderTime: reminderTime ?? this.reminderTime,
    budgetAlerts: budgetAlerts ?? this.budgetAlerts,
  );
}

final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsController, NotificationPrefs>(
      NotificationPrefsController.new,
    );

class NotificationPrefsController extends Notifier<NotificationPrefs> {
  static const _kDaily = 'notif_daily';
  static const _kTime = 'notif_time'; // minutes after midnight
  static const _kBudget = 'notif_budget';

  @override
  NotificationPrefs build() {
    final p = ref.read(sharedPreferencesProvider);
    final minutes = p?.getInt(_kTime) ?? 21 * 60;
    return NotificationPrefs(
      dailyReminder: p?.getBool(_kDaily) ?? false,
      reminderTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      budgetAlerts: p?.getBool(_kBudget) ?? false,
    );
  }

  /// Turns the daily reminder on (asking permission first) or off.
  /// Returns false if permission was refused.
  Future<bool> setDailyReminder(bool on) async {
    if (on && !await Notifications.instance.requestPermission()) return false;
    if (on) unawaited(Notifications.instance.initPush());
    state = state.copyWith(dailyReminder: on);
    await ref.read(sharedPreferencesProvider)?.setBool(_kDaily, on);
    on
        ? await Notifications.instance.scheduleDailyReminder(state.reminderTime)
        : await Notifications.instance.cancelDailyReminder();
    return true;
  }

  Future<void> setReminderTime(TimeOfDay t) async {
    state = state.copyWith(reminderTime: t);
    await ref
        .read(sharedPreferencesProvider)
        ?.setInt(_kTime, t.hour * 60 + t.minute);
    if (state.dailyReminder) {
      await Notifications.instance.scheduleDailyReminder(t);
    }
  }

  Future<bool> setBudgetAlerts(bool on) async {
    if (on && !await Notifications.instance.requestPermission()) return false;
    if (on) unawaited(Notifications.instance.initPush());
    state = state.copyWith(budgetAlerts: on);
    await ref.read(sharedPreferencesProvider)?.setBool(_kBudget, on);
    return true;
  }
}

/// Which budget alert (80% or over) to send for [p], if any, given what
/// was already sent this month.
String? budgetAlertLevel(BudgetProgress p, Set<String> sent, String month) {
  final cat = p.budget.category;
  if (p.isOver && !sent.contains('$month|$cat|over')) return 'over';
  if (p.isNear && p.budget.alertAt80 && !sent.contains('$month|$cat|near')) {
    return 'near';
  }
  return null;
}

/// Watches budgets and notifies once per month when one reaches 80% or
/// goes over. Kept alive by the app shell.
final budgetAlertsProvider = Provider<void>((ref) {
  ref.listen<List<BudgetProgress>>(budgetProgressProvider, (_, list) async {
    if (!ref.read(notificationPrefsProvider).budgetAlerts) return;
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) return;
    final now = DateTime.now();
    final month = '${now.year}-${now.month}';
    final sent = {...?prefs.getStringList('notif_budget_sent')}
      ..removeWhere((k) => !k.startsWith('$month|'));
    for (final p in list) {
      final level = budgetAlertLevel(p, sent, month);
      if (level == null) continue;
      final cat = p.budget.category;
      sent.add('$month|$cat|$level');
      if (level == 'over') sent.add('$month|$cat|near');
      await Notifications.instance.show(
        cat.hashCode & 0x7fffffff,
        level == 'over' ? '$cat is over budget' : '$cat is almost used up',
        level == 'over'
            ? 'You\'ve spent more than your ${cat.toLowerCase()} budget this month.'
            : 'You\'ve used ${(p.ratio * 100).round()}% of your $cat budget.',
      );
    }
    await prefs.setStringList('notif_budget_sent', sent.toList());
  });
});

/// FCM background messages are shown by the system; nothing to do here,
/// but a top-level handler must exist.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}
