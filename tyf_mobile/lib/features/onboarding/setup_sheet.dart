import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/utils/money.dart';
import '../budgets/data/budget_repository.dart';
import '../budgets/widgets/budget_sheet.dart';
import '../categories/data/category_repository.dart';
import '../categories/widgets/category_editor_sheet.dart';
import '../transactions/data/transaction_options.dart';
import '../transactions/screens/add_transaction_sheet.dart';

/// Set to true right after a sign-in; the app shell shows [SetupSheet]
/// once and resets it.
class SetupPrompt extends Notifier<bool> {
  @override
  bool build() => false;
  void request() => state = true;
  void consume() => state = false;
}

final setupPromptProvider = NotifierProvider<SetupPrompt, bool>(
  SetupPrompt.new,
);

/// Opens the guided setup: pick or create a category → (optional) set its
/// monthly budget → add the first entry for it.
Future<void> showSetupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const SetupSheet(),
  );
}

class SetupSheet extends ConsumerStatefulWidget {
  const SetupSheet({super.key});

  @override
  ConsumerState<SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends ConsumerState<SetupSheet> {
  String? _category;

  Future<void> _newCategory() async {
    final before = {
      for (final c in ref.read(categorySetProvider).expense) c.name,
    };
    await showCategoryEditor(context, kind: CategoryKind.expense);
    if (!mounted) return;
    final added = ref
        .read(categorySetProvider)
        .expense
        .where((c) => !before.contains(c.name))
        .firstOrNull;
    if (added != null) setState(() => _category = added.name);
  }

  Future<void> _addEntry(EntryType type) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final saved = await showAddTransactionSheet(
      context,
      initialType: type,
      initialCategory: type == EntryType.transfer ? null : _category,
    );
    if (saved != null && mounted) {
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('You\'re all set. Tap + any time to add more.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cats = ref.watch(categorySetProvider).expense;
    final budgets = ref.watch(budgetsProvider).value ?? const [];
    final budget = budgets.where((b) => b.category == _category).firstOrNull;
    final picked = cats.where((c) => c.name == _category).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        0,
        AppSpace.xl,
        AppSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Let\'s set things up',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Three quick steps. Skip any you don\'t need.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.xl),

          // 1. Category
          _Step(
            number: 1,
            title: 'Choose a category',
            done: picked != null,
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.sm),
                    child: ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New'),
                      onPressed: _newCategory,
                    ),
                  ),
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.sm),
                      child: ChoiceChip(
                        label: Text('${c.emoji} ${c.name}'),
                        selected: c.name == _category,
                        onSelected: (_) => setState(() => _category = c.name),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),

          // 2. Budget
          _Step(
            number: 2,
            title: 'Set a monthly budget',
            subtitle: 'Optional',
            done: budget != null,
            enabled: picked != null,
            child: picked == null
                ? Text(
                    'Pick a category first.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          showBudgetSheet(context, category: picked.name),
                      icon: Icon(
                        budget == null
                            ? Icons.savings_outlined
                            : Icons.edit_outlined,
                        size: 18,
                      ),
                      label: Text(
                        budget == null
                            ? 'Budget for ${picked.emoji} ${picked.name}'
                            : '${Money.format(budget.limitPaise)}/month · Edit',
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpace.md),

          // 3. First entry
          _Step(
            number: 3,
            title: 'Add your first entry',
            child: Row(
              children: [
                for (final (type, icon) in const [
                  (EntryType.expense, Icons.arrow_upward_rounded),
                  (EntryType.income, Icons.arrow_downward_rounded),
                  (EntryType.transfer, Icons.swap_horiz_rounded),
                ]) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.md,
                        ),
                      ),
                      onPressed: () => _addEntry(type),
                      icon: Icon(icon, size: 18),
                      label: FittedBox(child: Text(type.label)),
                    ),
                  ),
                  if (type != EntryType.transfer)
                    const SizedBox(width: AppSpace.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I\'ll do this later'),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.child,
    this.subtitle,
    this.done = false,
    this.enabled = true,
  });

  final int number;
  final String title;
  final String? subtitle;
  final bool done;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.5,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: done
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  foregroundColor: done
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                  child: done
                      ? const Icon(Icons.check_rounded, size: 16)
                      : Text(
                          '$number',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (subtitle != null)
                  StatusPill(subtitle!, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            child,
          ],
        ),
      ),
    );
  }
}
