import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import '../data/goal.dart';
import 'goal_ring.dart';

/// Goal details: big ring, plan, and Add savings / Withdraw / Edit.
Future<void> showGoalSheet(BuildContext context, String goalId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => GoalSheet(goalId: goalId),
    );

class GoalSheet extends ConsumerWidget {
  const GoalSheet({super.key, required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref
        .watch(goalsProvider)
        .where((g) => g.id == goalId)
        .firstOrNull;
    if (goal == null) return const SizedBox(height: 120);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = goal.isDone ? FinanceColors.income : scheme.primary;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit goal',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      showAddTransactionScreen(context, editing: goal.entry),
                ),
                IconButton(
                  tooltip: 'Delete goal',
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: () => _delete(context, ref, goal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: GoalRing(
                ratio: goal.ratio,
                color: color,
                size: 180,
                stroke: 14,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      goal.isDone ? '🎉' : '${(goal.ratio * 100).floor()}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      goal.isDone ? 'Goal reached' : 'saved',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _Fact('Saved', Money.format(goal.savedPaise)),
                _Fact('Target', Money.format(goal.targetPaise)),
                _Fact(
                  goal.isDone ? 'Done' : 'To go',
                  goal.isDone ? '✓' : Money.format(goal.leftPaise),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    goal.isOverdue
                        ? Icons.schedule_rounded
                        : Icons.event_available_rounded,
                    color: goal.isOverdue ? scheme.error : scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      goal.isDone
                          ? 'You reached this goal. Well done!'
                          : goal.isOverdue
                          ? 'Target date ${DateFormat('d MMM y').format(goal.targetDate)} has passed. Edit the goal to set a new date.'
                          : 'Save ${Money.format(goal.perMonthPaise)} a month to reach it by ${DateFormat('MMM y').format(goal.targetDate)}.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: goal.savedPaise > 0
                        ? () => _contribute(context, ref, goal, withdraw: true)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                    label: const Text('Withdraw'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: () => _contribute(context, ref, goal),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add savings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Goal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${goal.name}"?'),
        content: const Text('This removes the goal and its progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(entriesProvider.notifier).delete(goal.id);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _contribute(
    BuildContext context,
    WidgetRef ref,
    Goal goal, {
    bool withdraw = false,
  }) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _AmountDialog(goal: goal, withdraw: withdraw),
    );
    if (amount == null) return;
    final saved = withdraw
        ? (goal.savedPaise - amount).clamp(0, goal.savedPaise)
        : goal.savedPaise + amount;
    await ref
        .read(entriesProvider.notifier)
        .edit(goal.id, goal.entry.data.withSaved(saved));
    if (!context.mounted) return;
    final reached = !goal.isDone && saved >= goal.targetPaise;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          reached
              ? '🎉 ${goal.name} reached!'
              : '${Money.format(amount)} ${withdraw ? 'withdrawn from' : 'added to'} ${goal.name}',
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: t.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Amount entry with quick picks, including "this month's share".
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.goal, required this.withdraw});
  final Goal goal;
  final bool withdraw;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final p = parsePaise(_c.text);
    final max = widget.withdraw ? widget.goal.savedPaise : null;
    setState(() {
      _error = p == null
          ? 'Enter an amount, e.g. 500'
          : (max != null && p > max)
          ? 'You have ${Money.format(max)} saved'
          : null;
    });
    if (_error == null) Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final picks = <int>{
      if (!widget.withdraw && g.perMonthPaise > 0) g.perMonthPaise,
      50000,
      100000,
      500000,
      if (!widget.withdraw && g.leftPaise > 0) g.leftPaise,
    }.toList();
    String label(int p) => p == g.perMonthPaise && !widget.withdraw
        ? 'Monthly ${Money.format(p)}'
        : p == g.leftPaise && !widget.withdraw
        ? 'All ${Money.format(p)}'
        : Money.format(p);

    return AlertDialog(
      title: Text(widget.withdraw ? 'Withdraw' : 'Add savings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in picks)
                ActionChip(
                  label: Text(label(p)),
                  onPressed: () => setState(() {
                    _c.text = p % 100 == 0
                        ? '${p ~/ 100}'
                        : (p / 100).toStringAsFixed(2);
                    _error = null;
                  }),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.withdraw ? 'Withdraw' : 'Add'),
        ),
      ],
    );
  }
}
