import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/category_icons.dart';
import '../../../core/design/surface.dart';
import '../../../core/utils/money.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/entry.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import '../../transactions/widgets/swipe_entry.dart';

/// Lists one day's entries. Tap to edit; swipe left to delete (with
/// Undo), right to duplicate to today.
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
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final entries = ref.watch(entriesByDayProvider)[day] ?? const <Entry>[];
    final spent = entries
        .where((e) => e.type == EntryType.expense)
        .fold(0, (s, e) => s + e.amountPaise);
    final income = entries
        .where((e) => e.type == EntryType.income)
        .fold(0, (s, e) => s + e.amountPaise);
    final net = entries.fold(0, (s, e) => s + e.balanceEffect);

    final headerAmount = spent > 0 ? spent : net.abs();
    final txCountLabel =
        '${entries.length} ${entries.length == 1 ? 'transaction' : 'transactions'}';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: calendar icon badge, date, count + amount, + Add pill
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(
                      alpha: isDark ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    AppIcons.calendarMonthOutlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE, d MMMM').format(day),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        entries.isEmpty
                            ? 'No transactions'
                            : '$txCountLabel • ${Money.format(headerAmount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(AppIcons.add, size: 17),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.25),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.eventAvailableRounded,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nothing on this day',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + Add to log an expense or income.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (_, i) => SwipeEntry(
                  entry: entries[i],
                  child: EntryTile(entry: entries[i]),
                ),
              ),
            ),
          if (entries.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                decoration: BoxDecoration(
                  color: scheme.cardFill(0.7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.cardBorder),
                  boxShadow: scheme.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AppIcons.accountBalanceWalletOutlined,
                        size: 20,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spent > 0 && income == 0
                                ? 'Total Spent'
                                : 'Day Net',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            spent > 0 && income == 0
                                ? Money.format(spent)
                                : '${net < 0 ? '−' : ''}${Money.format(net.abs())}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (income > 0 && spent > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${Money.format(income)}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: FinanceColors.incomeOf(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '−${Money.format(spent)}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: FinanceColors.expenseOf(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

/// One entry row: category/type icon badge, title, payment icon + details,
/// signed amount, and chevron. Tap to edit.
class EntryTile extends ConsumerWidget {
  const EntryTile({super.key, required this.entry});
  final Entry entry;

  static IconData _paymentIcon(String? method) => switch (method) {
    'Credit card' || 'Debit card' => AppIcons.creditCardRounded,
    'Cash' => AppIcons.paymentsOutlined,
    'Wallet' => AppIcons.accountBalanceWalletOutlined,
    'UPI' || 'Net banking' || 'Bank account' => AppIcons.accountBalanceOutlined,
    _ => AppIcons.labelOutline,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final d = entry.data;
    final emoji = ref.watch(categorySetProvider).emojiFor(d.category);
    final subtitle = [
      if (d.category != null && d.category != entry.title) d.category,
      if (entry.type == EntryType.transfer && d.name != null)
        '${d.fromAccount ?? '?'} → ${d.toAccount ?? '?'}',
      if (d.subcategory != null) d.subcategory,
      if (d.paymentMethod != null) d.paymentMethod,
      if (d.repeat != null) 'Repeats',
      if (entry.seriesId != null) 'Recurring',
    ].join(' · ');

    final (sign, color) = switch (entry.type) {
      EntryType.income => ('+', FinanceColors.incomeOf(context)),
      EntryType.expense => ('−', FinanceColors.expenseOf(context)),
      _ => ('', scheme.primary),
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: () => showAddTransactionScreen(context, editing: entry),
      leading: emoji != null
          ? CategoryTile(name: d.category, glyph: emoji, size: 44)
          : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
              ),
              child: Icon(entry.type.icon, size: 20, color: color),
            ),
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Icon(
              entry.type == EntryType.transfer
                  ? AppIcons.swapHorizRounded
                  : _paymentIcon(d.paymentMethod),
              size: 13,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                subtitle.isEmpty ? entry.type.label : subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$sign${Money.format(entry.amountPaise)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            AppIcons.chevronRightRounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
