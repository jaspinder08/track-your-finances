import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/design/design.dart';
import '../../../core/navigation/page_route.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/screens/categories_screen.dart';
import '../data/budget_repository.dart';
import '../widgets/budget_progress_bar.dart';
import '../widgets/budget_sheet.dart';
import '../../../core/design/app_icons.dart';

/// Budgets tab.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) => const BudgetsView();
}

/// Month overview card, one card per category budget, and spending in
/// categories that don't have a budget yet.
class BudgetsView extends ConsumerWidget {
  const BudgetsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(budgetProgressProvider);
    final spend = ref.watch(monthSpendProvider);
    final budgeted = {for (final p in progress) p.budget.category};
    final unbudgeted =
        spend.entries.where((e) => !budgeted.contains(e.key)).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    if (progress.isEmpty) {
      return _Empty(topSpend: unbudgeted.map((e) => e.key).take(3).toList());
    }

    // Sort by % used descending so over-limit / warning categories appear first.
    final sorted = [...progress]..sort((a, b) => b.ratio.compareTo(a.ratio));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        FadeSlideIn(child: _Overview(progress: sorted)),
        const SizedBox(height: 22),
        const _SectionTitle(),
        const SizedBox(height: 10),
        for (final (i, p) in sorted.indexed) ...[
          FadeSlideIn(
            index: i + 1,
            child: _BudgetCard(p: p),
          ),
          const SizedBox(height: 10),
        ],
        if (unbudgeted.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionHeader('Spending without a budget'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, e) in unbudgeted.indexed) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 68,
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.25),
                    ),
                  _UnbudgetedTile(name: e.key, paise: e.value),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The month card: what's left to spend, pace pill, a "% used" ring, and a
/// clean Budgeted · Spent · Per day band.
class _Overview extends StatelessWidget {
  const _Overview({required this.progress});
  final List<BudgetProgress> progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final limit = progress.fold(0, (s, p) => s + p.budget.limitPaise);
    final spent = progress.fold(0, (s, p) => s + p.spentPaise);
    final left = limit - spent;
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1;
    final perDay = left > 0 ? left ~/ daysLeft : 0;
    final monthElapsed = now.day / daysInMonth;
    final isDark = theme.brightness == Brightness.dark;
    final on = scheme.onSurface;
    final dim = scheme.onSurfaceVariant;

    final (paceLabel, paceColor) = ratio > 1
        ? ('Over budget', FinanceColors.expenseOf(context))
        : ratio > monthElapsed + 0.08
        ? ('Spending fast', budgetWarning)
        : ('On track', FinanceColors.incomeOf(context));

    final ringColor = ratio > 1
        ? FinanceColors.expenseOf(context)
        : ratio >= 0.8
        ? budgetWarning
        : scheme.primary;

    return HeroCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${DateFormat.MMMM().format(now)} Budget',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: dim,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: paceColor.withValues(
                                alpha: isDark ? 0.20 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              paceLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: paceColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedMoney(
                          left.abs(),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: on,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        left >= 0
                            ? 'left to spend this month'
                            : 'over budget this month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: left >= 0
                              ? dim
                              : FinanceColors.expenseOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _Ring(ratio: ratio, color: ringColor),
              ],
            ),
          ),
          // Clean 3-column stats band.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.35 : 0.45,
              ),
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _Stat(label: 'Budgeted', value: Money.format(limit)),
                  _Divider(),
                  _Stat(
                    label: 'Spent',
                    value: Money.format(spent),
                    valueColor: FinanceColors.expenseOf(context),
                  ),
                  _Divider(),
                  _Stat(
                    label: perDay > 0 ? 'Safe / day' : 'Days left',
                    value: perDay > 0 ? Money.format(perDay) : '$daysLeft',
                    valueColor: FinanceColors.incomeOf(context),
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: 4),
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: t.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular "% used" ring with a theme-aware track.
class _Ring extends StatelessWidget {
  const _Ring({required this.ratio, required this.color});
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final trackColor = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.25 : 0.45,
    );
    return TweenAnimationBuilder<double>(
      key: ValueKey(TabVisit.of(context)),
      tween: Tween(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: 92,
        height: 92,
        child: CustomPaint(
          painter: _RingPainter(
            v.clamp(0, 1).toDouble(),
            color,
            trackColor,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(v * 100).round()}%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'used',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.trackColor);
  final double value;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.5;
    final r = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
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
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.trackColor != trackColor;
}

/// "Category Budgets" with a clean Manage action.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Category Budgets',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: scheme.primary,
          ),
          onPressed: () => Navigator.of(
            context,
          ).push(appPageRoute<void>(const CategoriesScreen())),
          icon: const Icon(AppIcons.settingsOutlined, size: 16),
          label: const Text('Manage'),
        ),
      ],
    );
  }
}

/// One category budget: icon tile, name, status pill, % used,
/// "₹spent of ₹limit" with "₹left left" (or "₹over over"), and a pill bar.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.p});
  final BudgetProgress p;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = budgetColor(context, p.ratio);
    final name = p.budget.category;
    final pct = (p.ratio * 100).round();
    final remaining = p.budget.limitPaise - p.spentPaise;

    return AppCard(
      onTap: () => showBudgetSheet(context, category: name),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CategoryTile(name: name, glyph: p.option?.emoji ?? '💸', size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (p.isOver || (p.isNear && p.budget.alertAt80))
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: StatusPill(
                                p.isOver ? 'Over' : 'Almost there',
                                color: color,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pct%',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.isOver ? color : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${Money.format(p.spentPaise)} of ${Money.format(p.budget.limitPaise)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      remaining >= 0
                          ? '${Money.format(remaining)} left'
                          : '${Money.format(remaining.abs())} over',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: remaining >= 0
                            ? scheme.onSurfaceVariant
                            : FinanceColors.expenseOf(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                BudgetProgressBar(ratio: p.ratio, color: color, height: 7),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnbudgetedTile extends ConsumerWidget {
  const _UnbudgetedTile({required this.name, required this.paise});
  final String name;
  final int paise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emoji = ref.watch(categorySetProvider).emojiFor(name) ?? '💸';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: CategoryTile(name: name, glyph: emoji, size: 42),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${Money.format(paise)} this month'),
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: () => showBudgetSheet(context, category: name),
        child: const Text('Set budget'),
      ),
    );
  }
}

/// First-run screen with a clear call to action and quick picks.
class _Empty extends ConsumerWidget {
  const _Empty({required this.topSpend});
  final List<String> topSpend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categorySetProvider);
    final picks = {...topSpend, 'Food', 'Travel', 'Shopping'}.take(4).toList();
    return EmptyState(
      emoji: '🎯',
      title: 'No budgets yet',
      message:
          'Set a monthly limit for a category and TYF will show how much is left as you spend.',
      actionLabel: 'Set a budget',
      onAction: () => showBudgetSheet(context),
      footer: Column(
        children: [
          Text(
            'Quick start',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final name in picks)
                ActionChip(
                  avatar: CategoryTile(
                    name: name,
                    glyph: cats.emojiFor(name) ?? '💸',
                    size: 24,
                  ),
                  label: Text(name),
                  onPressed: () => showBudgetSheet(context, category: name),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          TextButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(appPageRoute<void>(const CategoriesScreen())),
            icon: const Icon(AppIcons.gridViewRounded, size: 18),
            label: const Text('Manage categories'),
          ),
        ],
      ),
    );
  }
}
