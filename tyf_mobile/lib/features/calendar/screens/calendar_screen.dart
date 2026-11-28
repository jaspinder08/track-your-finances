import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/shell/top_bar.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/navigation/page_route.dart';
import '../../../core/utils/money.dart';
import '../../accounts/account_balances.dart';
import '../../accounts/accounts_screen.dart';
import '../../transactions/data/entry.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';
import '../../../core/design/surface.dart';
import '../calendar_month_provider.dart';
import '../widgets/day_entries_sheet.dart';

/// Home tab: month summary header, category spend bar, and month calendar.
/// Tap any day to open its bottom sheet.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  void _open(BuildContext context, DateTime day) =>
      showDayEntriesSheet(context, day);

  static int _computeStreak(Map<DateTime, List<Entry>> byDay, DateTime today) {
    var cursor = byDay.containsKey(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var streak = 0;
    while (byDay.containsKey(cursor) && byDay[cursor]!.isNotEmpty) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final light = scheme.isLight;
    final month = ref.watch(selectedMonthProvider);
    final entries = ref.watch(entriesProvider).value ?? const <Entry>[];
    final byDay = ref.watch(entriesByDayProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;
    final asOf = isCurrentMonth
        ? today
        : DateTime(month.year, month.month + 1, 0);
    final balancePaise = accountBalances(
      entries,
      asOf,
    ).values.fold(0, (s, v) => s + v);
    final hidden = ref.watch(hideBalanceProvider);

    // Grid: Monday on/before the 1st to Sunday on/after the last day.
    final first = DateTime(month.year, month.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final last = DateTime(month.year, month.month + 1, 0);
    final end = last.add(Duration(days: 7 - last.weekday));
    final days = List.generate(
      end.difference(start).inDays + 1,
      (i) => DateTime(start.year, start.month, start.day + i),
    );

    var monthIncome = 0, monthExpense = 0, maxDayExpense = 0;
    final categorySpend = <String, int>{};
    for (final e in byDay.entries) {
      if (e.key.year != month.year || e.key.month != month.month) continue;
      var dayExpense = 0;
      for (final x in e.value) {
        if (x.type == EntryType.income) monthIncome += x.amountPaise;
        if (x.type == EntryType.expense) {
          dayExpense += x.amountPaise;
          final cat = x.data.category ?? 'Other';
          categorySpend[cat] = (categorySpend[cat] ?? 0) + x.amountPaise;
        }
      }
      monthExpense += dayExpense;
      if (dayExpense > maxDayExpense) maxDayExpense = dayExpense;
    }

    final streak = _computeStreak(byDay, today);
    final sortedCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary header: Balance line, Spent in <Month>, big total, earned + streak
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(
                          context,
                        ).push(appPageRoute<void>(const AccountsScreen())),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Balance',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hidden
                                  ? '₹ • • • • •'
                                  : '${balancePaise < 0 ? '−' : ''}${Money.format(balancePaise.abs())}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: balancePaise < 0
                                    ? FinanceColors.expenseOf(context)
                                    : scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkResponse(
                        radius: 16,
                        onTap: () =>
                            ref.read(hideBalanceProvider.notifier).toggle(),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            hidden
                                ? AppIcons.visibilityOffOutlined
                                : AppIcons.visibilityOutlined,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Spent in ${DateFormat('MMMM').format(month)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Money.format(monthExpense),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.15,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '+${Money.format(monthIncome)} earned',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: FinanceColors.incomeOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(
                              alpha: light ? 0.10 : 0.22,
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.trackChangesRounded,
                                size: 13,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$streak-day streak',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CategorySpendBar(
                    categories: sortedCategories,
                    totalExpense: monthExpense,
                  ),
                ],
              ),
            ),
            if (byDay.isEmpty) ...[
              const SizedBox(height: 14),
              const _FirstRunHint(),
            ],
            const SizedBox(height: 14),
            // The month grid, on its own panel (unchanged).
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              decoration: BoxDecoration(
                color: scheme.cardFill(0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final d in [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ])
                        Expanded(
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, grid) {
                      final rows = (days.length / 7).ceil();
                      // Space left for the grid (summary ≈ 140, panel +
                      // weekday row ≈ 60, nav bar ≈ 110).
                      final avail = box.maxHeight - 140 - 60 - 110;
                      final cellW = (grid.maxWidth - 6 * 6) / 7;
                      final cellH = ((avail - 6 * (rows - 1)) / rows)
                          .clamp(cellW * 1.1, cellW * 1.9)
                          .toDouble();
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: cellW / cellH,
                        ),
                        itemCount: days.length,
                        itemBuilder: (context, i) {
                          final day = days[i];
                          final entries = byDay[day] ?? const <Entry>[];
                          int total(EntryType t) => entries
                              .where((e) => e.type == t)
                              .fold(0, (s, e) => s + e.amountPaise);
                          final expense = total(EntryType.expense);
                          return _DayCell(
                            day: day,
                            inMonth: day.month == month.month,
                            isToday: day == today,
                            income: total(EntryType.income),
                            expense: expense,
                            heat: day.month == month.month && maxDayExpense > 0
                                ? expense / maxDayExpense
                                : 0,
                            hasTransfer: entries.any(
                              (e) => e.type == EntryType.transfer,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _open(context, day);
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colourful segmented spending bar + legend dots for top categories.
class _CategorySpendBar extends StatelessWidget {
  const _CategorySpendBar({
    required this.categories,
    required this.totalExpense,
  });

  final List<MapEntry<String, int>> categories;
  final int totalExpense;

  static const _palette = [
    Color(0xFFF06A35), // coral/orange
    Color(0xFFE5A01D), // amber
    Color(0xFF1F9EB3), // teal
    Color(0xFFE5457A), // pink
    Color(0xFF8B5CF6), // violet
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (totalExpense <= 0 || categories.isEmpty) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(100),
        ),
      );
    }

    final top = categories.take(4).toList();
    final rest = categories.skip(4).fold<int>(0, (s, e) => s + e.value);
    final segments = <MapEntry<String, int>>[
      ...top,
      if (rest > 0) MapEntry('Other', rest),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                flex: segments[i].value.clamp(1, 1 << 30),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: _palette[i % _palette.length],
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (var i = 0; i < top.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _palette[i % _palette.length],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    top[i].key,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// One day tile. Spending days glow (stronger for heavier days), today
/// has an accent outline, the selected day a filled accent tint.
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
    final spent = expense > 0 && inMonth;
    final light = scheme.isLight;
    final active = income > 0 || expense > 0 || hasTransfer;

    final Gradient? gradient = spent && light
        // Light mode: a clean red wash that deepens with spending.
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              FinanceColors.expense.withValues(alpha: 0.07 + 0.22 * heat),
              FinanceColors.expense.withValues(alpha: 0.04 + 0.14 * heat),
            ],
          )
        : spent
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(
                scheme.primary,
                FinanceColors.expenseOf(context),
                0.35,
              )!.withValues(alpha: 0.25 + 0.4 * heat),
              FinanceColors.expense.withValues(alpha: 0.12 + 0.3 * heat),
            ],
          )
        : null;
    final Color? fill = spent
        ? null
        : isToday
        ? scheme.primary.withValues(alpha: 0.12)
        : inMonth
        ? (light
              ? const Color(0xFFF5F6F9)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.35))
        : scheme.surfaceContainerHighest.withValues(alpha: 0.12);
    final borderColor = isToday
        ? scheme.primary
        : spent
        ? FinanceColors.expense.withValues(
            alpha: light ? 0.18 + 0.4 * heat : 0.35 + 0.5 * heat,
          )
        : Colors.transparent;

    // One announcement per day instead of loose numbers: date, what
    // happened, and what a tap does.
    final label = [
      DateFormat('EEEE d MMMM').format(day),
      if (isToday) 'today',
      if (expense > 0) 'spent ${Money.format(expense)}',
      if (income > 0) 'earned ${Money.format(income)}',
      if (hasTransfer) 'has a transfer',
      if (!active) 'nothing added',
    ].join(', ');

    return Semantics(
      button: true,
      label: label,
      hint: active ? 'Show entries' : 'Add an entry',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: fill,
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isToday ? 2 : 1),
            boxShadow: [
              if (spent && heat > 0.5 && !light)
                BoxShadow(
                  color: FinanceColors.expense.withValues(alpha: 0.25 * heat),
                  blurRadius: 14,
                  spreadRadius: -4,
                ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          // Scales down rather than overflow on small screens.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${day.day}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: active || isToday
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: inMonth
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                if (income > 0)
                  _CellAmount(
                    '+${Money.compact(income)}',
                    FinanceColors.incomeOf(context),
                  ),
                if (expense > 0)
                  _CellAmount(
                    '−${Money.compact(expense)}',
                    spent && !light
                        ? const Color(0xFFFF8A92)
                        : FinanceColors.expenseOf(context),
                  ),
                if (hasTransfer)
                  Icon(
                    AppIcons.swapHorizRounded,
                    size: 12,
                    color: scheme.primary,
                    semanticLabel: 'Transfer',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ),
  );
}

/// Shown until the first entry: what to do, instead of ₹0 cards.
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
        borderRadius: BorderRadius.circular(16),
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
                  style: theme.textTheme.titleSmall,
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
