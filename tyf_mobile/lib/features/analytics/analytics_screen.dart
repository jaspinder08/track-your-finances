import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/theme/app_theme.dart';
import '../../core/design/app_icons.dart';
import '../../core/design/design.dart';
import '../../core/navigation/page_route.dart';
import '../../core/utils/money.dart';
import '../budgets/data/budget_repository.dart';
import '../budgets/widgets/budget_progress_bar.dart';
import '../categories/data/category_repository.dart';
import '../history/history_screen.dart';
import '../reports/data/month_report.dart';
import '../reports/widgets/charts.dart';
import '../transactions/data/entry_repository.dart';
import 'analytics_data.dart';

/// Analytics tab: savings, totals, spending by category, income vs
/// expense, budgets, payment methods and the savings trend.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  var _period = AnalyticsPeriod.thisMonth;
  bool _allCategories = false;

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categorySetProvider);
    final data = AnalyticsData.compute(
      ref.watch(entriesProvider).value ?? const [],
      _period,
      emojiFor: cats.emojiFor,
    );
    final budgets = ref.watch(budgetProgressProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        _PeriodSwitch(
          value: _period,
          onChanged: (p) {
            HapticFeedback.selectionClick();
            setState(() => _period = p);
          },
        ),
        const SizedBox(height: 14),
        FadeSlideIn(child: _SavingsCard(data: data)),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 1,
          child: Row(
            children: [
              _TotalTile(
                label: 'Total Income',
                paise: data.income,
                icon: AppIcons.accountBalanceWalletOutlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              _TotalTile(
                label: 'Total Expenses',
                paise: data.expense,
                icon: AppIcons.receiptLongOutlined,
                color: FinanceColors.expense,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 2,
          child: _SpendingByCategory(
            data: data,
            showAll: _allCategories,
            onToggleAll: () => setState(() => _allCategories = !_allCategories),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(index: 3, child: _IncomeVsExpense(months: data.months)),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 4,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _BudgetVsActual(budgets: budgets)),
                const SizedBox(width: 10),
                Expanded(child: _PaymentMethods(data: data)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(index: 5, child: _TrendCard(months: data.months)),
      ],
    );
  }
}

// ── Shared panel ──────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.compact = false,
  });

  /// Half-width panel: smaller title that may wrap.
  final bool compact;
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHigh.withValues(alpha: 0.75),
            Color.lerp(
              scheme.surfaceContainerHigh,
              scheme.primary,
              0.08,
            )!.withValues(alpha: 0.75),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary, size: compact ? 20 : 22),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: compact
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.titleMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Period switch ─────────────────────────────────────────────────────

class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({required this.value, required this.onChanged});
  final AnalyticsPeriod value;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          for (final p in AnalyticsPeriod.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: p == value ? scheme.primary : Colors.transparent,
                    boxShadow: [
                      if (p == value)
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          spreadRadius: -4,
                        ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          if (p == AnalyticsPeriod.thisMonth) ...[
                            Icon(
                              AppIcons.eventRounded,
                              size: 16,
                              color: p == value
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            p.label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: p == value
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Savings ───────────────────────────────────────────────────────────

class _SavingsCard extends StatelessWidget {
  const _SavingsCard({required this.data});
  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = scheme.onSurface;
    final dim = scheme.onSurfaceVariant;
    final saved = data.saved;
    final change = data.savedChange;
    final up = (change ?? 0) >= 0;
    final than = switch (data.period) {
      AnalyticsPeriod.thisMonth => 'last month',
      AnalyticsPeriod.last6Months => 'the 6 months before',
      AnalyticsPeriod.thisYear => 'last year',
    };

    return HeroCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      AppIcons.trendingUpRounded,
                      color: up ? FinanceColors.income : FinanceColors.expense,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      saved >= 0 ? 'Your Savings' : 'Overspent',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: dim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedMoney(
                    saved.abs(),
                    style: theme.textTheme.displaySmall?.copyWith(color: on),
                  ),
                ),
                const SizedBox(height: 6),
                if (change != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${up ? '↑' : '↓'} ${(change.abs() * 100).round()}%',
                          style: TextStyle(
                            color: up
                                ? FinanceColors.income
                                : FinanceColors.expense,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: ' compared to $than'),
                      ],
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: dim,
                    ),
                  )
                else
                  Text(
                    data.isEmpty
                        ? 'Nothing recorded yet'
                        : 'Keep going to see how you compare',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: dim,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SavingsRing(rate: data.savingsRate ?? 0),
        ],
      ),
    );
  }
}

class _SavingsRing extends StatelessWidget {
  const _SavingsRing({required this.rate});
  final double rate;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(TabVisit.of(context)),
    tween: Tween(begin: 0, end: rate),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => SizedBox.square(
      dimension: 88,
      child: CustomPaint(
        painter: _ArcPainter(v, FinanceColors.income, stroke: 9),
        child: Center(
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FinanceColors.income.withValues(alpha: 0.18),
            ),
            child: Tooltip(
              message: '${(rate * 100).round()}% of income saved',
              child: const Icon(
                AppIcons.pottedPlant,
                color: FinanceColors.income,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.value, this.color, {this.stroke = 10});
  final double value;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.value != value || o.color != color;
}

// ── Totals ────────────────────────────────────────────────────────────

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.paise,
    required this.icon,
    required this.color,
  });
  final String label;
  final int paise;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.14),
              scheme.surfaceContainerHigh.withValues(alpha: 0.6),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Money.format(paise),
                      style: theme.textTheme.titleLarge,
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

// ── Spending by category ──────────────────────────────────────────────

class _SpendingByCategory extends StatelessWidget {
  const _SpendingByCategory({
    required this.data,
    required this.showAll,
    required this.onToggleAll,
  });
  final AnalyticsData data;
  final bool showAll;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slices = data.categories;
    final colors = [for (final s in slices) categoryColor(s.name)];
    final shown = showAll ? slices : slices.take(4).toList();

    return _Panel(
      icon: AppIcons.pieChartRounded,
      title: 'Spending by Category',
      trailing: slices.length > 4
          ? TextButton(
              onPressed: onToggleAll,
              child: Text(showAll ? 'Show less' : 'View All'),
            )
          : null,
      child: slices.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No spending in this period yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          : Row(
              children: [
                DonutChart(
                  slices: slices,
                  colors: colors,
                  size: 140,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        child: Text(
                          Money.format(data.expense),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        'Total Spent',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      for (final (i, s) in shown.indexed)
                        Tooltip(
                          message: 'See ${s.name} entries',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.of(context).push(
                              appPageRoute<void>(
                                HistoryScreen(category: s.name),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors[i],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  Text(
                                    Money.compact(s.paise),
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  SizedBox(
                                    width: 42,
                                    child: Text(
                                      '${(s.share * 100).round()}%',
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

// ── Income vs expense bars ────────────────────────────────────────────

const _expenseBar = Color(0xFF8B5CF6);

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _IncomeVsExpense extends StatelessWidget {
  const _IncomeVsExpense({required this.months});
  final List<MonthTotals> months;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Panel(
      icon: AppIcons.barChartRounded,
      title: 'Income vs Expense',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Legend(scheme.primary, 'Income'),
          const SizedBox(width: 10),
          const _Legend(_expenseBar, 'Expense'),
        ],
      ),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('${TabVisit.of(context)}${months.length}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => SizedBox(
          height: 170,
          child: CustomPaint(
            painter: _BarsPainter(
              months: months,
              t: t,
              income: scheme.primary,
              expense: _expenseBar,
              text: scheme.onSurfaceVariant,
              grid: scheme.outlineVariant.withValues(alpha: 0.2),
              highlight: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounds a max value up to a clean axis top (e.g. 17,300 → 20,000).
double _niceMax(double v) {
  if (v <= 0) return 1;
  final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  for (final m in [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (m * mag >= v) return m * mag;
  }
  return 10 * mag;
}

String _axis(double rupees) => rupees >= 100000
    ? '${(rupees / 100000).toStringAsFixed(rupees % 100000 == 0 ? 0 : 1)}L'
    : rupees >= 1000
    ? '${(rupees / 1000).toStringAsFixed(rupees % 1000 == 0 ? 0 : 1)}k'
    : rupees.toStringAsFixed(0);

void _text(
  Canvas c,
  String s,
  Offset at,
  Color color, {
  double size = 10,
  bool center = false,
  bool right = false,
  FontWeight weight = FontWeight.w500,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontFamily: 'Inter',
        fontWeight: weight,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = center
      ? at.dx - tp.width / 2
      : right
      ? at.dx - tp.width
      : at.dx;
  tp.paint(c, Offset(dx, at.dy - tp.height / 2));
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.months,
    required this.t,
    required this.income,
    required this.expense,
    required this.text,
    required this.grid,
    required this.highlight,
  });
  final List<MonthTotals> months;
  final double t;
  final Color income, expense, text, grid, highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;
    const left = 34.0, bottom = 22.0, top = 6.0;
    final chartH = size.height - bottom - top;
    final chartW = size.width - left;
    final maxV = months.fold<int>(
      0,
      (m, x) => math.max(m, math.max(x.income, x.expense)),
    );
    final top4 = _niceMax(maxV / 100);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + chartH * (1 - i / 4);
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
      _text(
        canvas,
        _axis(top4 * i / 4),
        Offset(left - 6, y),
        text,
        right: true,
      );
    }
    final slot = chartW / months.length;
    final barW = math.min(14.0, slot * 0.28);
    for (final (i, m) in months.indexed) {
      final cx = left + slot * (i + 0.5);
      final last = i == months.length - 1;
      if (last) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - slot / 2 + 2, 0, cx + slot / 2 - 2, size.height),
            const Radius.circular(10),
          ),
          Paint()..color = highlight,
        );
      }
      void bar(int paise, double x, Color c) {
        final h = (paise / 100 / top4) * chartH * t;
        if (h <= 0) return;
        final rect = Rect.fromLTWH(x, top + chartH - h, barW, h);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c, c.withValues(alpha: 0.7)],
            ).createShader(rect),
        );
      }

      bar(m.income, cx - barW - 2, income);
      bar(m.expense, cx + 2, expense);
      _text(
        canvas,
        DateFormat.MMM().format(m.month),
        Offset(cx, size.height - bottom / 2 + 2),
        last ? Colors.white : text,
        center: true,
        size: 11,
        weight: last ? FontWeight.w700 : FontWeight.w500,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.t != t || o.months != months;
}

// ── Budget vs actual ──────────────────────────────────────────────────

class _BudgetVsActual extends StatelessWidget {
  const _BudgetVsActual({required this.budgets});
  final List<BudgetProgress> budgets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _Panel(
      icon: AppIcons.trackChangesRounded,
      title: 'Budget vs Actual',
      compact: true,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: budgets.isEmpty
          ? Text(
              'Set budgets on the Budgets tab to compare.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (final b in budgets.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 58,
                          child: Text(
                            b.budget.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        Expanded(
                          child: BudgetProgressBar(
                            ratio: b.ratio,
                            color: budgetColor(context, b.ratio),
                            height: 7,
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${(b.ratio * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: b.isOver
                                  ? FinanceColors.expense
                                  : scheme.onSurfaceVariant,
                            ),
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

// ── Payment methods ───────────────────────────────────────────────────

const _methodColors = [
  Color(0xFF5B8DEF),
  Color(0xFF8B5CF6),
  Color(0xFFEF8A3C),
  Color(0xFF2EC4C4),
  Color(0xFFF2557E),
  Color(0xFF34C77B),
];

class _PaymentMethods extends StatelessWidget {
  const _PaymentMethods({required this.data});
  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slices = data.paymentMethods;
    return _Panel(
      icon: AppIcons.creditCardRounded,
      title: 'Payment Methods',
      compact: true,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: slices.isEmpty
          ? Text(
              'No spending yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                DonutChart(
                  slices: slices,
                  colors: _methodColors,
                  size: 92,
                  center: const SizedBox.shrink(),
                ),
                const SizedBox(height: 10),
                for (final (i, s) in slices.take(4).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _methodColors[i % _methodColors.length],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        Text(
                          '${(s.share * 100).round()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
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

// ── Net savings trend ─────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.months});
  final List<MonthTotals> months;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Panel(
      icon: AppIcons.showChartRounded,
      title: 'Monthly Trend (Net Savings)',
      child: TweenAnimationBuilder<double>(
        key: ValueKey('${TabVisit.of(context)}${months.length}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => SizedBox(
          height: 130,
          child: CustomPaint(
            painter: _LinePainter(
              values: [for (final m in months) m.income - m.expense],
              labels: [
                for (final m in months) DateFormat.MMM().format(m.month),
              ],
              t: t,
              line: Color.lerp(scheme.primary, _expenseBar, 0.5)!,
              text: scheme.onSurfaceVariant,
              grid: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.labels,
    required this.t,
    required this.line,
    required this.text,
    required this.grid,
  });
  final List<int> values;
  final List<String> labels;
  final double t;
  final Color line, text, grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 40.0, bottom = 20.0, top = 26.0, right = 12.0;
    final h = size.height - bottom - top;
    final w = size.width - left - right;
    final lo = math.min(0, values.reduce(math.min)) / 100;
    final hi = _niceMax(math.max(1, values.reduce(math.max) / 100));
    double y(int paise) => top + h * (1 - ((paise / 100) - lo) / (hi - lo));
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [lo, (lo + hi) / 2, hi]) {
      final yy = top + h * (1 - (v - lo) / (hi - lo));
      canvas.drawLine(
        Offset(left, yy),
        Offset(size.width - right, yy),
        gridPaint,
      );
      _text(
        canvas,
        '${v < 0 ? '−' : ''}₹${_axis(v.abs())}',
        Offset(left - 6, yy),
        text,
        right: true,
      );
    }
    final step = values.length == 1 ? 0.0 : w / (values.length - 1);
    final pts = [
      for (final (i, v) in values.indexed)
        Offset(left + step * i, y((v * t).round())),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(path)
      ..lineTo(pts.last.dx, top + h)
      ..lineTo(pts.first.dx, top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.25), line.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, top, size.width, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    for (final (i, p) in pts.indexed) {
      canvas.drawCircle(p, 4.5, Paint()..color = line);
      canvas.drawCircle(p, 2, Paint()..color = Colors.white);
      _text(
        canvas,
        labels[i],
        Offset(p.dx, size.height - bottom / 2 + 2),
        text,
        center: true,
        size: 11,
      );
    }
    // Callout on the latest month.
    final last = pts.last;
    final v = values.last;
    final label = '${v < 0 ? '−' : ''}${Money.compact(v.abs())}';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bw = tp.width + 14, bh = tp.height + 8;
    final bx = (last.dx - bw / 2).clamp(left, size.width - bw);
    final box = Rect.fromLTWH(bx, last.dy - bh - 10, bw, bh);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(8)),
      Paint()..color = line,
    );
    tp.paint(canvas, Offset(box.left + 7, box.top + 4));
  }

  @override
  bool shouldRepaint(_LinePainter o) => o.t != t || o.values != values;
}
