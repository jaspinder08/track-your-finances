import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/design/design.dart';
import '../../transactions/data/transaction_options.dart';
import '../../transactions/screens/add_transaction_sheet.dart';
import '../data/goal.dart';
import '../widgets/goal_ring.dart';
import '../widgets/goal_sheet.dart';

/// Goals half of the Budgets tab: overall progress, then one card per goal.
class GoalsView extends ConsumerWidget {
  const GoalsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    if (goals.isEmpty) return const _Empty();
    final active = goals.where((g) => !g.isDone).toList();
    final done = goals.where((g) => g.isDone).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _Overview(goals: goals),
        const SizedBox(height: 24),
        if (active.isNotEmpty) ...[
          const SectionHeader('In progress'),
          for (final (i, g) in active.indexed) ...[
            FadeSlideIn(
              index: i + 1,
              child: _GoalCard(goal: g),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (done.isNotEmpty) ...[
          const SizedBox(height: 8),
          const SectionHeader('Reached 🎉'),
          for (final g in done) ...[
            _GoalCard(goal: g),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.goals});
  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const on = HeroCard.foreground;
    final dim = on.withValues(alpha: 0.75);
    final saved = goals.fold(0, (s, g) => s + g.savedPaise);
    final target = goals.fold(0, (s, g) => s + g.targetPaise);
    final monthly = goals.fold(0, (s, g) => s + g.perMonthPaise);
    final reached = goals.where((g) => g.isDone).length;

    return HeroCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved towards goals',
                  style: theme.textTheme.labelLarge?.copyWith(color: dim),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedMoney(
                    saved,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: on,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'of ${Money.format(target)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: dim),
                ),
                const SizedBox(height: 14),
                Text(
                  monthly > 0
                      ? 'Put aside ${Money.format(monthly)}/month to stay on track'
                      : 'All goals reached',
                  style: theme.textTheme.labelMedium?.copyWith(color: on),
                ),
                Text(
                  '$reached of ${goals.length} reached',
                  style: theme.textTheme.labelSmall?.copyWith(color: dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GoalRing(
            ratio: target == 0 ? 0 : saved / target,
            color: on,
            trackColor: on.withValues(alpha: 0.2),
            size: 88,
            stroke: 9,
            child: Text(
              '${target == 0 ? 0 : (saved / target * 100).floor()}%',
              style: theme.textTheme.titleMedium?.copyWith(
                color: on,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = goal.isDone ? FinanceColors.income : scheme.primary;
    final subtitle = goal.isDone
        ? 'Reached · ${Money.format(goal.targetPaise)}'
        : goal.isOverdue
        ? 'Target date passed · ${Money.format(goal.leftPaise)} to go'
        : '${Money.format(goal.leftPaise)} to go · by ${DateFormat('MMM y').format(goal.targetDate)}';

    return AppCard(
      onTap: () => showGoalSheet(context, goal.id),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GoalRing(
            ratio: goal.ratio,
            color: color,
            size: 56,
            stroke: 6,
            child: goal.isDone
                ? Icon(Icons.check_rounded, color: color)
                : Text(
                    '${(goal.ratio * 100).floor()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Money.format(goal.savedPaise)} of ${Money.format(goal.targetPaise)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: goal.isOverdue
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!goal.isDone && !goal.isOverdue)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Money.format(goal.perMonthPaise),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                Text(
                  'per month',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => EmptyState(
    emoji: '🏁',
    title: 'No goals yet',
    message:
        'Saving for a laptop, a trip or an emergency fund? Set a target and TYF shows how much to put aside each month.',
    actionLabel: 'Create a goal',
    actionIcon: Icons.flag_rounded,
    // A full page (no nav bar), so centre in the whole space.
    bottomInset: AppSpace.xxxl,
    onAction: () =>
        showAddTransactionSheet(context, initialType: EntryType.goal),
  );
}
