import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme/app_theme.dart';
import '../../core/design/app_icons.dart';
import '../../core/design/design.dart';
import '../../core/utils/money.dart';
import '../transactions/data/entry.dart';
import '../transactions/data/entry_repository.dart';
import '../transactions/data/transaction_options.dart';
import 'sms_parser.dart';

/// Reads recent bank SMS (only when the user taps Scan), lists the
/// debits and credits found, and adds the ones the user ticks.
/// Nothing leaves the phone.
class SmsScanScreen extends ConsumerStatefulWidget {
  const SmsScanScreen({super.key});

  @override
  ConsumerState<SmsScanScreen> createState() => _SmsScanScreenState();
}

class _SmsScanScreenState extends ConsumerState<SmsScanScreen> {
  static const _days = 30;

  List<SmsTxn>? _found;
  final _picked = <int>{};
  bool _busy = false;
  String? _error;

  /// Already in TYF: same type, amount and day.
  bool _alreadyAdded(SmsTxn t, List<Entry> entries) => entries.any(
    (e) =>
        !e.isDeleted &&
        e.type == t.type &&
        e.amountPaise == t.amountPaise &&
        DateUtils.isSameDay(e.date, t.date),
  );

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      setState(() {
        _busy = false;
        _error = status.isPermanentlyDenied
            ? 'SMS access is turned off. Allow it in the phone\'s app '
                  'settings to scan.'
            : 'TYF needs SMS access to find bank messages.';
      });
      return;
    }
    try {
      final since = DateTime.now().subtract(const Duration(days: _days));
      final msgs = await SmsQuery().querySms(
        kinds: [SmsQueryKind.inbox],
        count: 500,
      );
      final entries = ref.read(entriesProvider).value ?? const <Entry>[];
      final found = <SmsTxn>[];
      for (final m in msgs) {
        final date = m.date;
        if (date == null || date.isBefore(since) || m.body == null) continue;
        final t = parseBankSms(m.body!, date);
        if (t != null) found.add(t);
      }
      found.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _found = found;
        _picked
          ..clear()
          ..addAll([
            for (var i = 0; i < found.length; i++)
              if (!_alreadyAdded(found[i], entries)) i,
          ]);
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Couldn\'t read messages on this phone.';
      });
    }
  }

  Future<void> _addPicked() async {
    final found = _found!;
    final n = ref.read(entriesProvider.notifier);
    for (final i in _picked) {
      final t = found[i];
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
    if (!mounted) return;
    final count = _picked.length;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Added $count ${count == 1 ? 'transaction' : 'transactions'}. '
          'Pick categories for them in History.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = ref.watch(entriesProvider).value ?? const <Entry>[];
    final found = _found;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan SMS')),
      bottomNavigationBar: found == null || found.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _picked.isEmpty ? null : _addPicked,
                  icon: const Icon(AppIcons.addRounded),
                  label: Text(
                    _picked.isEmpty
                        ? 'Select transactions to add'
                        : 'Add ${_picked.length} '
                              '${_picked.length == 1 ? 'transaction' : 'transactions'}',
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      AppIcons.chatText,
                      color: HeroCard.foreground,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Find transactions in your SMS',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: HeroCard.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'TYF reads bank and UPI messages from the last $_days days '
                  'on this phone and shows the money that moved. You choose '
                  'what to add. Messages never leave your phone.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: HeroCard.foreground.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    backgroundColor: HeroCard.foreground.withValues(
                      alpha: 0.16,
                    ),
                    foregroundColor: HeroCard.foreground,
                  ),
                  onPressed: _busy ? null : _scan,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.searchRounded),
                  label: Text(found == null ? 'Scan SMS' : 'Scan again'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
            ),
            if (_error!.contains('settings'))
              TextButton(
                onPressed: openAppSettings,
                child: const Text('Open app settings'),
              ),
          ],
          if (found != null) ...[
            const SizedBox(height: 18),
            Text(
              found.isEmpty
                  ? 'No bank transactions found in the last $_days days.'
                  : '${found.length} found · already-added ones are unticked',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            for (final (i, t) in found.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FoundTile(
                  t: t,
                  picked: _picked.contains(i),
                  added: _alreadyAdded(t, entries),
                  onChanged: (v) =>
                      setState(() => v ? _picked.add(i) : _picked.remove(i)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FoundTile extends StatelessWidget {
  const _FoundTile({
    required this.t,
    required this.picked,
    required this.added,
    required this.onChanged,
  });
  final SmsTxn t;
  final bool picked;
  final bool added;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isIncome = t.type == EntryType.income;
    final color = isIncome ? FinanceColors.income : const Color(0xFFFF6B78);
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: picked
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!picked),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
          child: Row(
            children: [
              Checkbox(value: picked, onChanged: (v) => onChanged(v ?? false)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.party ?? (isIncome ? 'Money received' : 'Payment'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      [
                        DateFormat('d MMM, h:mm a').format(t.date),
                        t.paymentMethod,
                        if (t.accountTail != null) '••${t.accountTail}',
                        if (added) 'Already added',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: added ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '−'}${Money.format(t.amountPaise)}',
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
