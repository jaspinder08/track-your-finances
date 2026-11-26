import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/utils/money.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import '../widgets/day_entries_sheet.dart';

/// Home tab: month summary cards, a month calendar, and a card for the
/// selected day. Tap a day to select it; tap it again (or "View details")
/// to see its entries, or add one if it's empty.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = DateUtils.dateOnly(DateTime.now());

  void _shift(int months) {
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  void _open(DateTime day, List<Entry> entries) => entries.isEmpty
      ? showAddTransactionScreen(context, initialDate: day)
      : showDayEntriesSheet(context, day);

  void _tapDay(DateTime day, List<Entry> entries) {
    if (day == _selected) {
      _open(day, entries);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _selected = day;
      if (day.month != _month.month || day.year != _month.year) {
        _month = DateTime(day.year, day.month);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final byDay = ref.watch(entriesByDayProvider);
    final today = DateUtils.dateOnly(DateTime.now());

    // Grid: Monday on/before the 1st to Sunday on/after the last day.
    final first = DateTime(_month.year, _month.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final last = DateTime(_month.year, _month.month + 1, 0);
    final end = last.add(Duration(days: 7 - last.weekday));
    final days = List.generate(
      end.difference(start).inDays + 1,
      (i) => DateTime(start.year, start.month, start.day + i),
    );

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
    final isThisMonth =
        _month.year == today.year && _month.month == today.month;
    final daysCounted = _month.isAfter(today)
        ? 0
        : isThisMonth
        ? today.day
        : last.day;

    Widget roundButton(IconData icon, String tip, VoidCallback onTap) =>
        IconButton.filledTonal(
          tooltip: tip,
          style: IconButton.styleFrom(
            shape: const CircleBorder(),
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            foregroundColor: scheme.primary,
          ),
          onPressed: onTap,
          icon: Icon(icon),
        );

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        child: Column(
          children: [
            // Month: ‹ November 2026 ›
            Row(
              children: [
                roundButton(
                  AppIcons.chevronLeftRounded,
                  'Previous month',
                  () => _shift(-1),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      DateFormat('MMMM y').format(_month),
                      key: ValueKey(_month),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                roundButton(
                  AppIcons.chevronRightRounded,
                  'Next month',
                  () => _shift(1),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (byDay.isEmpty)
              const _FirstRunHint()
            else
              Row(
                children: [
                  _StatCard(
                    label: 'Income',
                    value: Money.format(monthIncome),
                    icon: AppIcons.southWestRounded,
                    color: FinanceColors.income,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'Spent',
                    value: Money.format(monthExpense),
                    icon: AppIcons.northEastRounded,
                    color: FinanceColors.expense,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'Per day',
                    value: Money.format(
                      daysCounted == 0 ? 0 : monthExpense ~/ daysCounted,
                    ),
                    icon: AppIcons.todayRounded,
                    color: scheme.primary,
                  ),
                ],
              ),
            const SizedBox(height: 14),
            // The month grid, on its own panel.
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
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
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 0.82,
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
                        inMonth: day.month == _month.month,
                        isToday: day == today,
                        isSelected: day == _selected,
                        income: total(EntryType.income),
                        expense: expense,
                        heat: day.month == _month.month && maxDayExpense > 0
                            ? expense / maxDayExpense
                            : 0,
                        hasTransfer: entries.any(
                          (e) => e.type == EntryType.transfer,
                        ),
                        onTap: () => _tapDay(day, entries),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SelectedDayCard(
              day: _selected,
              entries: byDay[_selected] ?? const [],
              onOpen: () => _open(_selected, byDay[_selected] ?? const []),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the three summary cards: tinted, with a soft wave at the foot.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        height: 78,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.16),
              scheme.surfaceContainerHigh.withValues(alpha: 0.6),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _WavePainter(color))),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 8, 6),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.18),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
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

/// A soft rising wave along the bottom of a stat card.
class _WavePainter extends CustomPainter {
  const _WavePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = Path()
      ..moveTo(0, h - 6)
      ..cubicTo(w * 0.35, h - 2, w * 0.55, h - 4, w * 0.75, h - 12)
      ..quadraticBezierTo(w * 0.9, h - 18, w, h - 20);
    final fill = Path.from(line)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.color != color;
}

/// One day tile. Spending days glow (stronger for heavier days), today
/// has an accent outline, the selected day a filled accent tint.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.income,
    required this.expense,
    required this.heat,
    required this.hasTransfer,
    required this.onTap,
  });
  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
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
    final active = income > 0 || expense > 0 || hasTransfer;

    final Gradient? gradient = spent
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(
                scheme.primary,
                FinanceColors.expense,
                0.35,
              )!.withValues(alpha: 0.25 + 0.4 * heat),
              FinanceColors.expense.withValues(alpha: 0.12 + 0.3 * heat),
            ],
          )
        : null;
    final Color? fill = spent
        ? null
        : isSelected
        ? scheme.primary.withValues(alpha: 0.22)
        : isToday
        ? scheme.primary.withValues(alpha: 0.12)
        : inMonth
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.12);
    final borderColor = isSelected || isToday
        ? scheme.primary
        : spent
        ? FinanceColors.expense.withValues(alpha: 0.35 + 0.5 * heat)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: fill,
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected || isToday ? 2 : 1,
          ),
          boxShadow: [
            if (spent && heat > 0.5)
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
                _CellAmount('+${Money.compact(income)}', FinanceColors.income),
              if (expense > 0)
                _CellAmount(
                  '−${Money.compact(expense)}',
                  spent ? const Color(0xFFFF8A92) : FinanceColors.expense,
                ),
              if (hasTransfer)
                Icon(
                  AppIcons.swapHorizRounded,
                  size: 12,
                  color: scheme.primary,
                  semanticLabel: 'Transfer',
                ),
              if (isToday || active)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: spent ? const Color(0xFFFF8A92) : scheme.primary,
                  ),
                ),
            ],
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

/// The selected day: date, what happened, and "View details".
class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.day,
    required this.entries,
    required this.onOpen,
  });
  final DateTime day;
  final List<Entry> entries;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = entries.length;
    final net = entries.fold(0, (s, e) => s + e.balanceEffect);
    final summary = n == 0
        ? 'No transactions'
        : '$n ${n == 1 ? 'transaction' : 'transactions'}'
              '${net == 0 ? '' : ' · ${net < 0 ? '−' : '+'}${Money.format(net.abs())}'}';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.18),
            ),
            child: Icon(AppIcons.todayRounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Column(
                key: ValueKey('$day$n$net'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('d MMMM, y').format(day),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: scheme.primary.withValues(alpha: 0.16),
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      n == 0 ? 'Add entry' : 'View details',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      n == 0
                          ? AppIcons.addRounded
                          : AppIcons.arrowForwardRounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
                  'Tap a day below twice, or the + button, to note what you '
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
