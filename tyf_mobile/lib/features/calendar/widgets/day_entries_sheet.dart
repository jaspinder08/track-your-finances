import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../transactions/data/entry_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/transaction_options.dart';
import '../../transactions/screens/add_transaction_screen.dart';

/// Lists one day's entries. Tap one to edit it; swipe left to delete it.
Future<void> showDayEntriesSheet(BuildContext context, DateTime day) async {
  final addMore = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DayEntriesSheet(day: day),
  );
  if (addMore == true && context.mounted) {
    await showAddTransactionScreen(context, initialDate: day);
  }
}

class DayEntriesSheet extends ConsumerWidget {
  const DayEntriesSheet({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(entriesByDayProvider)[day] ?? const <Entry>[];
    final net = entries.fold(0, (s, e) => s + e.balanceEffect);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE, d MMMM').format(day),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Nothing on this day', textAlign: TextAlign.center),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in entries)
                    Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: theme.colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      onDismissed: (_) =>
                          ref.read(entriesProvider.notifier).delete(e.id),
                      child: EntryTile(entry: e),
                    ),
                ],
              ),
            ),
          if (entries.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Text('Net', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '${net < 0 ? '−' : ''}${Money.format(net.abs())}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One entry row: emoji, title, details, signed amount. Tap to edit.
class EntryTile extends ConsumerWidget {
  const EntryTile({super.key, required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = entry.data;
    final emoji = ref.watch(categorySetProvider).emojiFor(d.category);
    final subtitle = [
      if (d.subcategory != null) d.subcategory,
      if (d.paymentMethod != null) d.paymentMethod,
      if (d.repeat != null) 'Repeats',
      if (entry.seriesId != null) 'Recurring',
    ].join(' · ');
    final (sign, color) = switch (entry.type) {
      EntryType.income => ('+', FinanceColors.income),
      EntryType.expense => ('−', FinanceColors.expense),
      _ => ('', theme.colorScheme.onSurface),
    };

    return ListTile(
      onTap: () => showAddTransactionScreen(context, editing: entry),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
        child: emoji != null
            ? Text(emoji, style: const TextStyle(fontSize: 20))
            : Icon(entry.type.icon, color: theme.colorScheme.primary),
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? Text(entry.type.label) : Text(subtitle),
      trailing: Text(
        '$sign${Money.format(entry.amountPaise)}',
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
