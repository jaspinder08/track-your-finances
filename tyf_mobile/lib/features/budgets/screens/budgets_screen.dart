import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../../../core/design/design.dart';
import '../../categories/data/category_repository.dart';
import '../data/budget_repository.dart';
import '../widgets/budget_progress_bar.dart';
import '../widgets/budget_sheet.dart';

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
        _Overview(progress: progress),
        const SizedBox(height: 24),
        SectionHeader(
          'Category budgets',
          trailing: AddButton(onPressed: () => showBudgetSheet(context)),
        ),
        for (final p in progress) ...[
          _BudgetCard(p: p),
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

/// Accent gradient card: what's left this month, a ring, and a daily pace.
class _Overview extends StatelessWidget {
  const _Overview({required this.progress});
  final List<BudgetProgress> progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = progress.fold(0, (s, p) => s + p.budget.limitPaise);
    final spent = progress.fold(0, (s, p) => s + p.spentPaise);
    final left = limit - spent;
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1;
    final perDay = left > 0 ? left ~/ daysLeft : 0;
    final over = progress.where((p) => p.isOver).length;
    final near = progress.where((p) => p.isNear).length;
    const on = HeroCard.foreground;
    final dim = on.withValues(alpha: 0.75);

    return HeroCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat.MMMM().format(now)} budget',
                      style: theme.textTheme.labelLarge?.copyWith(color: dim),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Money.format(left.abs()),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: on,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      left >= 0 ? 'left to spend' : 'over budget',
                      style: theme.textTheme.bodyMedium?.copyWith(color: dim),
                    ),
                  ],
                ),
              ),
              _Ring(ratio: ratio, color: on),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(label: 'Budgeted', value: Money.format(limit), color: on),
              _Stat(label: 'Spent', value: Money.format(spent), color: on),
              _Stat(
                label: perDay > 0 ? 'Per day' : 'Days left',
                value: perDay > 0 ? Money.format(perDay) : '$daysLeft',
                color: on,
              ),
            ],
          ),
          if (over + near > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: on.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: on),
                  const SizedBox(width: 8),
                  Text(
                    [
                      if (over > 0) '$over over budget',
                      if (near > 0) '$near almost used up',
                    ].join(' · '),
                    style: theme.textTheme.labelMedium?.copyWith(color: on),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
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
          Text(
            label,
            style: t.labelSmall?.copyWith(color: color.withValues(alpha: 0.7)),
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

/// Circular "% used" ring on the overview card.
class _Ring extends StatelessWidget {
  const _Ring({required this.ratio, required this.color});
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: ratio),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: 84,
        height: 84,
        child: CustomPaint(
          painter: _RingPainter(v.clamp(0, 1).toDouble(), color),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(v * 100).round()}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
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
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final track = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * math.pi, false, track);
    if (value > 0) {
      canvas.drawArc(r, -math.pi / 2, 2 * math.pi * value, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

/// One category budget: emoji, spent of limit, left/over, progress bar.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.p});
  final BudgetProgress p;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = budgetColor(context, p.ratio);
    final name = p.budget.category;

    return AppCard(
      onTap: () => showBudgetSheet(context, category: name),
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge.emoji(p.option?.emoji ?? '💸', color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                            padding: const EdgeInsets.only(left: AppSpace.sm),
                            child: StatusPill(
                              p.isOver ? 'Over' : 'Almost there',
                              color: color,
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
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.format(p.leftPaise.abs()),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: p.isOver ? color : scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    p.isOver ? 'over' : 'left',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          BudgetProgressBar(ratio: p.ratio, color: color),
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
    final theme = Theme.of(context);
    final emoji = ref.watch(categorySetProvider).emojiFor(name) ?? '💸';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
      title: Text(name),
      subtitle: Text('${Money.format(paise)} spent this month'),
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          visualDensity: VisualDensity.compact,
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
                  avatar: Text(cats.emojiFor(name) ?? '💸'),
                  label: Text(name),
                  onPressed: () => showBudgetSheet(context, category: name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
