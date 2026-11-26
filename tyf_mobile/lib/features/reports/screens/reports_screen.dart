import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../../../core/design/design.dart';
import '../../calendar/widgets/day_entries_sheet.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import '../data/month_report.dart';
import '../widgets/charts.dart';
import '../../../core/design/app_icons.dart';

/// Reports tab: month summary, spending by category, 6-month trend,
/// biggest expenses and how you paid.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedSlice;

  void _setMonth(DateTime m) => setState(() {
    _month = DateTime(m.year, m.month);
    _selectedSlice = null;
  });

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesProvider).value ?? const [];
    final cats = ref.watch(categorySetProvider);
    final report = MonthReport.build(
      entries,
      _month,
      emojiFor: (n) =>
          cats.expense.where((c) => c.name == n).firstOrNull?.emoji,
    );
    final now = DateTime.now();
    final canGoNext = _month.isBefore(DateTime(now.year, now.month));

    final switcher = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: _MonthSwitcher(
        month: _month,
        onPrev: () => _setMonth(DateTime(_month.year, _month.month - 1)),
        onNext: canGoNext
            ? () => _setMonth(DateTime(_month.year, _month.month + 1))
            : null,
      ),
    );

    if (report.isEmpty) {
      return Column(
        children: [
          switcher,
          Expanded(
            child: EmptyState(
              icon: AppIcons.insightsRounded,
              title: 'Nothing in ${DateFormat.MMMM().format(_month)}',
              message:
                  'Add income and expenses and you\'ll see where your money goes.',
              actionLabel: 'Add a transaction',
              onAction: () => showAddTransactionScreen(context),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.navBarClearance,
      ),
      children: [
        _MonthSwitcher(
          month: _month,
          onPrev: () => _setMonth(DateTime(_month.year, _month.month - 1)),
          onNext: canGoNext
              ? () => _setMonth(DateTime(_month.year, _month.month + 1))
              : null,
        ),
        ...[
          _Summary(report: report),
          const SizedBox(height: 16),
          if (report.categories.isNotEmpty) ...[
            _Card(
              title: 'Where it went',
              child: _CategoryBreakdown(
                report: report,
                selected: _selectedSlice,
                onSelect: (i) => setState(
                  () => _selectedSlice = _selectedSlice == i ? null : i,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _Card(
            title: 'Last 6 months',
            trailing: const _Legend(),
            child: TrendBars(
              months: report.trend,
              selected: _month,
              onTap: _setMonth,
            ),
          ),
          if (report.topExpenses.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Card(
              title: 'Biggest expenses',
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Column(
                children: [
                  for (final e in report.topExpenses) EntryTile(entry: e),
                ],
              ),
            ),
          ],
          if (report.paymentMethods.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Card(
              title: 'How you paid',
              child: Column(
                children: [
                  for (final s in report.paymentMethods) _MethodRow(slice: s),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: onPrev,
        icon: const Icon(AppIcons.chevronLeft),
        tooltip: 'Previous month',
      ),
      Expanded(
        child: Text(
          DateFormat.yMMMM().format(month),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(
        onPressed: onNext,
        icon: const Icon(AppIcons.chevronRight),
        tooltip: 'Next month',
      ),
    ],
  );
}

/// Accent card: saved this month, income, expense, savings rate.
class _Summary extends StatelessWidget {
  const _Summary({required this.report});
  final MonthReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const on = HeroCard.foreground;
    final dim = on.withValues(alpha: 0.75);
    final saved = report.saved;
    final rate = report.savingsRate;
    final vs = report.vsLastMonth;

    return HeroCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  saved >= 0 ? 'Saved this month' : 'Overspent this month',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: dim),
                ),
              ),
              const SizedBox(width: 8),
              if (rate != null)
                _Badge(text: '${(rate * 100).round()}% of income', color: on),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedMoney(
              saved.abs(),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: on,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Figure(
                icon: AppIcons.southWestRounded,
                label: 'Income',
                value: Money.format(report.income),
                color: on,
              ),
              _Figure(
                icon: AppIcons.northEastRounded,
                label: 'Spent',
                value: Money.format(report.expense),
                color: on,
              ),
              _Figure(
                icon: AppIcons.todayRounded,
                label: 'Per day',
                value: Money.format(report.perDay),
                color: on,
              ),
            ],
          ),
          if (vs != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  vs > 0
                      ? AppIcons.trendingUpRounded
                      : AppIcons.trendingDownRounded,
                  size: 18,
                  color: on,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    vs == 0
                        ? 'Same spending as last month'
                        : '${(vs.abs() * 100).round()}% ${vs > 0 ? 'more' : 'less'} spending than last month',
                    style: theme.textTheme.labelMedium?.copyWith(color: on),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 3),
              Text(
                label,
                style: t.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: t.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title,
          trailing: trailing,
          padding: EdgeInsets.only(
            left: padding.left < AppSpace.md ? AppSpace.md : 0,
            right: padding.right < AppSpace.md ? AppSpace.md : 0,
            bottom: AppSpace.md,
          ),
        ),
        child,
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;
    Widget dot(Color c) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(scheme.primary.withValues(alpha: 0.3)),
        const SizedBox(width: 4),
        Text('Income', style: style),
        const SizedBox(width: 10),
        dot(scheme.primary),
        const SizedBox(width: 4),
        Text('Spent', style: style),
      ],
    );
  }
}

/// Donut plus a tappable legend. Tap a row to highlight it; tap the
/// arrow to see that category's entries.
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.report,
    required this.selected,
    required this.onSelect,
  });
  final MonthReport report;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slices = report.categories;
    final colors = chartPalette(scheme.primary, slices.length);
    final sel = selected != null && selected! < slices.length
        ? slices[selected!]
        : null;

    return Column(
      children: [
        DonutChart(
          slices: slices,
          colors: colors,
          selected: selected,
          center: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Column(
              key: ValueKey(sel?.name),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sel?.emoji != null)
                  Text(sel!.emoji!, style: const TextStyle(fontSize: 22)),
                Text(
                  sel?.name ?? 'Spent',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  Money.format(sel?.paise ?? report.expense),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (sel != null)
                  Text(
                    '${(sel.share * 100).round()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors[selected!],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < slices.length; i++)
          FadeSlideIn(
            index: i,
            child: _CategoryRow(
              slice: slices[i],
              color: colors[i],
              selected: i == selected,
              month: report.month,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    required this.slice,
    required this.color,
    required this.selected,
    required this.month,
    required this.onTap,
  });
  final Slice slice;
  final Color color;
  final bool selected;
  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                slice.emoji ?? '💸',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          slice.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        Money.format(slice.paise),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: slice.share,
                            minHeight: 6,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.14),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${(slice.share * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'See ${slice.name} entries',
              visualDensity: VisualDensity.compact,
              icon: const Icon(AppIcons.chevronRightRounded),
              onPressed: () => _showEntries(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showEntries(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final list =
              (ref.watch(entriesProvider).value ?? const [])
                  .where(
                    (e) =>
                        e.type == EntryType.expense &&
                        (e.data.category ?? 'Other') == slice.name &&
                        e.date.year == month.year &&
                        e.date.month == month.month,
                  )
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));
          final theme = Theme.of(context);
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    '${slice.emoji ?? ''} ${slice.name} · ${DateFormat.MMMM().format(month)}'
                        .trim(),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final e in list)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 20, top: 4),
                              child: Text(
                                DateFormat('d MMM').format(e.date),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            EntryTile(entry: e),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({required this.slice});
  final Slice slice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            paymentMethodIcons[slice.name] ?? AppIcons.paymentsOutlined,
            size: 20,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(slice.name, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: slice.share,
                minHeight: 8,
                color: scheme.primary,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(
              Money.format(slice.paise),
              textAlign: TextAlign.right,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
