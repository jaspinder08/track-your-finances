import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme/app_theme.dart';
import '../../core/design/app_icons.dart';
import '../../core/utils/money.dart';
import '../transactions/data/entry.dart';
import '../transactions/data/entry_repository.dart';
import '../transactions/data/transaction_options.dart';
import 'sms_parser.dart';
import 'sms_watch.dart';

/// Scans bank and UPI SMS as soon as it opens, then lists what moved.
/// Transactions not seen before are labelled "New"; add one or all.
/// Messages never leave the phone.
class SmsScanScreen extends ConsumerStatefulWidget {
  const SmsScanScreen({super.key});

  @override
  ConsumerState<SmsScanScreen> createState() => _SmsScanScreenState();
}

enum _Stage { scanning, denied, blocked, error, done }

class _SmsScanScreenState extends ConsumerState<SmsScanScreen> {
  static const _days = 30;

  var _stage = _Stage.scanning;
  List<SmsTxn> _found = const [];
  Set<String> _newKeys = const {};
  final _added = <String>{};
  int _read = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  /// Already in TYF: same type, amount and day.
  bool _inTyf(SmsTxn t, List<Entry> entries) =>
      _added.contains(smsKey(t)) ||
      entries.any(
        (e) =>
            !e.isDeleted &&
            e.type == t.type &&
            e.amountPaise == t.amountPaise &&
            DateUtils.isSameDay(e.date, t.date),
      );

  Future<void> _scan() async {
    setState(() {
      _stage = _Stage.scanning;
      _read = 0;
    });
    final status = await Permission.sms.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(
        () => _stage = status.isPermanentlyDenied
            ? _Stage.blocked
            : _Stage.denied,
      );
      return;
    }
    // From now on, new bank SMS are detected and notified automatically.
    await startSmsWatch();
    try {
      final since = DateTime.now().subtract(const Duration(days: _days));
      final msgs = await SmsQuery().querySms(
        kinds: [SmsQueryKind.inbox],
        count: 600,
      );
      final seen = await loadSeen();
      final done = await loadDone();
      final found = <SmsTxn>[];
      for (final m in msgs) {
        final date = m.date;
        if (date == null || date.isBefore(since) || m.body == null) continue;
        final t = parseBankSms(m.body!, date);
        if (t != null && !found.any((f) => smsKey(f) == smsKey(t))) {
          found.add(t);
        }
        if (mounted && found.length % 5 == 0) setState(() => _read++);
      }
      found.sort((a, b) => b.date.compareTo(a.date));
      final keys = found.map(smsKey).toSet();
      if (!mounted) return;
      setState(() {
        _found = found;
        // First visit: nothing has been seen, so nothing is "New".
        _newKeys = seen.isEmpty ? {} : keys.difference(seen);
        _added.addAll(keys.intersection(done));
        _stage = _Stage.done;
      });
      await markSeen(keys);
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.error);
    }
  }

  Future<void> _add(List<SmsTxn> list) async {
    if (list.isEmpty) return;
    HapticFeedback.mediumImpact();
    final n = ref.read(entriesProvider.notifier);
    for (final t in list) {
      await n.add(
        EntryDraft(
          type: t.type,
          amountPaise: t.amountPaise,
          date: DateUtils.dateOnly(t.date),
          name: t.party,
          category: t.type == EntryType.income ? 'Other' : null,
          paymentMethod: t.paymentMethod,
          description: 'From SMS',
        ),
      );
    }
    await markDone(list.map(smsKey));
    if (!mounted) return;
    setState(() => _added.addAll(list.map(smsKey)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          list.length == 1
              ? 'Added ${list.single.party ?? 'transaction'}'
              : 'Added ${list.length} transactions',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = ref.watch(entriesProvider).value ?? const <Entry>[];
    final toAdd = [
      for (final t in _found)
        if (!_inTyf(t, entries)) t,
    ];
    final newCount = _found.where((t) => _newKeys.contains(smsKey(t))).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan SMS'),
        actions: [
          if (_stage == _Stage.done)
            IconButton(
              tooltip: 'Scan again',
              onPressed: _scan,
              icon: const Icon(AppIcons.cloudSyncOutlined),
            ),
        ],
      ),
      bottomNavigationBar: _stage == _Stage.done && toAdd.length > 1
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => _add(toAdd),
                  icon: const Icon(AppIcons.addRounded),
                  label: Text('Add all ${toAdd.length}'),
                ),
              ),
            )
          : null,
      body: switch (_stage) {
        _Stage.scanning => _Scanning(read: _read),
        _Stage.denied || _Stage.blocked => _Message(
          icon: AppIcons.chatText,
          title: 'Allow SMS access',
          body:
              'TYF reads bank and UPI messages on this phone to find your '
              'transactions. Messages never leave your phone.',
          action: _stage == _Stage.blocked ? 'Open settings' : 'Allow access',
          onAction: _stage == _Stage.blocked ? openAppSettings : _scan,
        ),
        _Stage.error => _Message(
          icon: AppIcons.infoOutlineRounded,
          title: 'Couldn\'t read messages',
          body: 'Something went wrong reading SMS on this phone.',
          action: 'Try again',
          onAction: _scan,
        ),
        _Stage.done when _found.isEmpty => const _Message(
          icon: AppIcons.checkCircleOutlineRounded,
          title: 'Nothing found',
          body:
              'No bank or UPI transactions in the last $_days days. New '
              'ones will show up here, and you\'ll get a notification.',
        ),
        _Stage.done => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                [
                  '${_found.length} found in the last $_days days',
                  if (newCount > 0) '$newCount new',
                  if (toAdd.isEmpty) 'all added',
                ].join(' · '),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final t in _found)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FoundTile(
                  t: t,
                  isNew: _newKeys.contains(smsKey(t)),
                  added: _inTyf(t, entries),
                  onAdd: () => _add([t]),
                ),
              ),
          ],
        ),
      },
    );
  }
}

/// The scanning state: a moving bar and what's happening.
class _Scanning extends StatelessWidget {
  const _Scanning({required this.read});
  final int read;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.chatText, size: 48, color: scheme.primary),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                minHeight: 6,
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 16),
            Text('Scanning messages…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Looking for bank and UPI transactions',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: onAction,
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoundTile extends StatelessWidget {
  const _FoundTile({
    required this.t,
    required this.isNew,
    required this.added,
    required this.onAdd,
  });
  final SmsTxn t;
  final bool isNew;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isIncome = t.type == EntryType.income;
    final color = isIncome ? FinanceColors.income : const Color(0xFFFF6B78);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNew && !added
              ? scheme.primary.withValues(alpha: 0.6)
              : scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
            ),
            child: Icon(
              isIncome
                  ? AppIcons.arrowDownwardRounded
                  : AppIcons.arrowUpwardRounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        t.party ?? (isIncome ? 'Money received' : 'Payment'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (isNew && !added) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'New',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  [
                    DateFormat('d MMM, h:mm a').format(t.date),
                    t.paymentMethod,
                    if (t.accountTail != null) '••${t.accountTail}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isIncome ? '+' : '−'}${Money.format(t.amountPaise)}',
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          added
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.checkRounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Added',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                )
              : FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: onAdd,
                  child: const Text('Add'),
                ),
        ],
      ),
    );
  }
}
