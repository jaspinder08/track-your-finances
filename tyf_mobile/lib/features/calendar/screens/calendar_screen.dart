import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import '../widgets/day_entries_sheet.dart';

/// Home tab: a month calendar. Each day shows its income and expense
/// totals; tap a day to see its entries (or add one if it's empty).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = ref.watch(entriesByDayProvider);
    final today = DateUtils.dateOnly(DateTime.now());

    // Grid starts on the Monday on/before the 1st, ends on the Sunday on/after the last day.
    final first = DateTime(_month.year, _month.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final last = DateTime(_month.year, _month.month + 1, 0);
    final end = last.add(Duration(days: 7 - last.weekday));
    final dayCount = end.difference(start).inDays + 1;
    final days = List.generate(
      dayCount,
      (i) => DateTime(start.year, start.month, start.day + i),
    );

    // Month totals for the summary strip.
    var monthIncome = 0, monthExpense = 0, maxDayExpense = 0;
    for (final e in byDay.entries) {
      if (e.key.year != _month.year || e.key.month != _month.month) continue;
      var dayExpense = 0;
      for (final x in e.value) {
        if (x.type == EntryType.income) monthIncome += x.amountPaise;
        if (x.type == EntryType.expense) dayExpense += x.amountPaise;
      }
      monthExpense += dayExpense;
      if (dayExpense > maxDayExpense) maxDayExpense = dayExpense;
    }
    // Days so far this month (all of it for past months), for the average.
    final isThisMonth =
        _month.year == today.year && _month.month == today.month;
    final daysCounted = _month.isAfter(today)
        ? 0
        : isThisMonth
        ? today.day
        : last.day;
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous month',
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    key: ValueKey(_month),
                    children: [
                      Text(
                        DateFormat.MMMM().format(_month),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_month.year}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next month',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: byDay.isEmpty
              ? const _FirstRunHint()
              : _MonthStrip(
                  income: monthIncome,
                  expense: monthExpense,
                  perDay: daysCounted == 0 ? 0 : monthExpense ~/ daysCounted,
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final (i, d) in [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ].indexed)
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: i >= 5
                          ? scheme.primary.withValues(alpha: 0.8)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              // Fit every week on screen above the floating nav bar.
              const bottomPad = 112.0, gap = 4.0;
              final rows = (days.length / 7).ceil();
              final cellW = (box.maxWidth - 24 - gap * 6) / 7;
              final cellH =
                  ((box.maxHeight - bottomPad - gap * (rows - 1)) / rows).clamp(
                    52.0,
                    96.0,
                  );
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, bottomPad),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: cellW / cellH,
                ),
                itemCount: days.length,
                itemBuilder: (context, i) {
                  final day = days[i];
                  final entries = byDay[day] ?? const <Entry>[];
                  int total(EntryType t) => entries
                      .where((e) => e.type == t)
                      .fold(0, (s, e) => s + e.amountPaise);
                  return _DayCell(
                    day: day,
                    inMonth: day.month == _month.month,
                    isToday: day == today,
                    income: total(EntryType.income),
                    expense: total(EntryType.expense),
                    // How heavy this day's spending was, 0..1 of the
                    // month's biggest day, for the heatmap tint.
                    heat: day.month == _month.month && maxDayExpense > 0
                        ? total(EntryType.expense) / maxDayExpense
                        : 0,
                    hasTransfer: entries.any(
                      (e) => e.type == EntryType.transfer,
                    ),
                    onTap: () => entries.isEmpty
                        ? showAddTransactionScreen(context, initialDate: day)
                        : showDayEntriesSheet(context, day),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Income · Spent · average spend per day for the visible month. (The
/// month's net isn't shown: the balance pill above already says it.)
class _MonthStrip extends StatelessWidget {
  const _MonthStrip({
    required this.income,
    required this.expense,
    required this.perDay,
  });
  final int income;
  final int expense;
  final int perDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget item(String label, String value, Color color, IconData icon) =>
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    Widget divider() => Container(
      width: 1,
      height: 28,
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          item(
            'Income',
            Money.format(income),
            FinanceColors.income,
            Icons.south_west_rounded,
          ),
          divider(),
          item(
            'Spent',
            Money.format(expense),
            FinanceColors.expense,
            Icons.north_east_rounded,
          ),
          divider(),
          item(
            'Per day',
            Money.format(perDay),
            scheme.primary,
            Icons.today_rounded,
          ),
        ],
      ),
    );
  }
}

/// One day: rounded tile, today filled with the accent, amounts below.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.income,
    required this.expense,
    required this.heat,
    required this.hasTransfer,
    required this.onTap,
  });
  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final int income;
  final int expense;
  final double heat;
  final bool hasTransfer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = income > 0 || expense > 0 || hasTransfer;
    // Heatmap: heavier spending days glow redder.
    final bg = isToday
        ? scheme.primary.withValues(alpha: 0.12)
        : heat > 0
        ? Color.alphaBlend(
            FinanceColors.expense.withValues(alpha: 0.08 + 0.30 * heat),
            scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          )
        : active
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.7)
        : inMonth
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.28)
        : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: isToday
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                )
              : null,
          padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Text(
                  '${day.day}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isToday || active
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isToday
                        ? scheme.onPrimary
                        : inMonth
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
              if (income > 0)
                _CellAmount('+${Money.compact(income)}', FinanceColors.income),
              if (expense > 0)
                _CellAmount(
                  '−${Money.compact(expense)}',
                  FinanceColors.expense,
                ),
              if (hasTransfer)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 14,
                    color: scheme.primary,
                    semanticLabel: 'Transfer',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny amount line inside a calendar cell.
class _CellAmount extends StatelessWidget {
  const _CellAmount(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// Shown until the first entry: what to do, instead of a row of ₹0.
class _FirstRunHint extends StatelessWidget {
  const _FirstRunHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('👋', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add your first transaction',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Tap any day below, or the + button, to note what you '
                  'spent or earned.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
