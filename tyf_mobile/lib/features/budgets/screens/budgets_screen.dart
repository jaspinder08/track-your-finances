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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        FadeSlideIn(child: _Overview(progress: progress)),
        const SizedBox(height: 24),
        const _SectionTitle(),
        const SizedBox(height: 12),
        for (final (i, p) in progress.indexed) ...[
          FadeSlideIn(
            index: i + 1,
            child: _BudgetCard(p: p),
          ),
          const SizedBox(height: 10),
        ],
        if (unbudgeted.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionHeader('Spending without a budget'),
          for (final e in unbudgeted)
            _UnbudgetedTile(name: e.key, paise: e.value),
        ],
      ],
    );
  }
}

/// The month card: what's left to spend, a "% used" ring, and a band of
/// Budgeted · Spent · Per day.
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
    final isDark = theme.brightness == Brightness.dark;
    final on = scheme.onSurface;
    final dim = scheme.onSurfaceVariant;

    return HeroCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              AppIcons.eventRounded,
                              size: 20,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              '${DateFormat.MMMM().format(now)} Budget',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedMoney(
                          left.abs(),
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: on,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        left >= 0
                            ? 'left to spend this month'
                            : 'over budget this month',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: left >= 0 ? dim : FinanceColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 90,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
                _Ring(ratio: ratio, color: scheme.primary),
              ],
            ),
          ),
          // Stats band.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
                  _Stat(
                    icon: AppIcons.accountBalanceWalletOutlined,
                    tint: scheme.primary,
                    label: 'Budgeted',
                    value: Money.format(limit),
                  ),
                  _Divider(),
                  _Stat(
                    icon: AppIcons.accountBalanceWalletOutlined,
                    tint: FinanceColors.expense,
                    label: 'Spent',
                    value: Money.format(spent),
                    valueColor: FinanceColors.expense,
                  ),
                  _Divider(),
                  _Stat(
                    icon: AppIcons.todayRounded,
                    tint: FinanceColors.income,
                    label: perDay > 0 ? 'Per day' : 'Days left',
                    value: perDay > 0 ? Money.format(perDay) : '$daysLeft',
                    valueColor: FinanceColors.income,
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
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final on = scheme.onSurface;
    final dim = scheme.onSurfaceVariant;
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: tint),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: t.labelSmall?.copyWith(
                    color: dim,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: t.titleSmall?.copyWith(color: valueColor ?? on),
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

/// Circular "% used" ring with a gradient arc.
class _Ring extends StatelessWidget {
  const _Ring({required this.ratio, required this.color});
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      key: ValueKey(TabVisit.of(context)),
      tween: Tween(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: 104,
        height: 104,
        child: CustomPaint(
          painter: _RingPainter(
            v.clamp(0, 1).toDouble(),
            ratio > 1 ? FinanceColors.expense : accent,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(v * 100).round()}%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: color),
                ),
                Text(
                  'used',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.75),
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
  _RingPainter(this.value, this.color);
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final r = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    final light = Color.lerp(color, Colors.white, 0.45)!;
    canvas.drawArc(
      r,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [light, color, light],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(r)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

/// "Category Budgets" with a Manage Categories pill.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(AppIcons.gridViewRounded, color: scheme.primary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Category Budgets',
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 19),
            ),
          ),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
            backgroundColor: scheme.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 38),
          ),
          onPressed: () => Navigator.of(
            context,
          ).push(appPageRoute<void>(const CategoriesScreen())),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.settingsOutlined, size: 17, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Manage Categories',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                AppIcons.chevronRightRounded,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One category budget: icon tile, name, "₹spent of ₹limit", % used,
/// and a progress bar. Tap to change the limit.
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

    return AppCard(
      onTap: () => showBudgetSheet(context, category: name),
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          CategoryTile(name: name, glyph: p.option?.emoji ?? '💸', size: 56),
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
                                fontSize: 17,
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
                    Text(
                      '$pct%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: p.isOver ? color : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${Money.format(p.spentPaise)} of ${Money.format(p.budget.limitPaise)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                BudgetProgressBar(ratio: p.ratio, color: color, height: 8),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(AppIcons.chevronRightRounded, color: scheme.onSurfaceVariant),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CategoryTile(name: name, glyph: emoji, size: 44),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${Money.format(paise)} this month'),
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
