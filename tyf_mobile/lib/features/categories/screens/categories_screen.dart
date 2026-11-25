import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/money.dart';
import '../../transactions/data/entry.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';
import '../data/category_repository.dart';
import '../widgets/category_editor_sheet.dart';

/// Which list the Categories tab shows. The + button reads this.
final categoryKindViewProvider =
    NotifierProvider<CategoryKindView, CategoryKind>(CategoryKindView.new);

class CategoryKindView extends Notifier<CategoryKind> {
  @override
  CategoryKind build() => CategoryKind.expense;
  void set(CategoryKind k) => state = k;
}

/// Categories tab: expense/income lists. Tap to edit, drag to reorder.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(categoryKindViewProvider);
    final list = ref.watch(categorySetProvider).of(kind);
    final now = DateTime.now();

    // This month's total and entry count per category, for the cards.
    final stats = <String, (int, int)>{};
    for (final Entry e in ref.watch(entriesProvider).value ?? const []) {
      if (e.type != kind.entryType) continue;
      if (e.date.year != now.year || e.date.month != now.month) continue;
      final c = e.data.category ?? '';
      final (sum, n) = stats[c] ?? (0, 0);
      stats[c] = (sum + e.amountPaise, n + 1);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<CategoryKind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: CategoryKind.expense,
                  icon: Icon(Icons.north_east_rounded),
                  label: Text('Expense'),
                ),
                ButtonSegment(
                  value: CategoryKind.income,
                  icon: Icon(Icons.south_west_rounded),
                  label: Text('Income'),
                ),
              ],
              selected: {kind},
              onSelectionChanged: (s) =>
                  ref.read(categoryKindViewProvider.notifier).set(s.first),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${list.length} categories · hold and drag to reorder',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (_) => _confirmReset(context, ref, kind),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'reset',
                    child: Text('Restore default categories'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: list.length,
            buildDefaultDragHandles: false,
            onReorder: (from, to) =>
                ref.read(categoriesProvider.notifier).reorder(kind, from, to),
            proxyDecorator: (child, _, _) =>
                Material(color: Colors.transparent, elevation: 6, child: child),
            itemBuilder: (context, i) {
              final c = list[i];
              final s = stats[c.name];
              return Padding(
                key: ValueKey('${kind.name}-${c.name}'),
                padding: const EdgeInsets.only(bottom: 10),
                child: ReorderableDelayedDragStartListener(
                  index: i,
                  child: _CategoryCard(
                    category: c,
                    monthPaise: s?.$1 ?? 0,
                    monthCount: s?.$2 ?? 0,
                    onTap: () =>
                        showCategoryEditor(context, kind: kind, existing: c),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    WidgetRef ref,
    CategoryKind kind,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore default ${kind.label.toLowerCase()} categories?'),
        content: const Text(
          'Your own categories in this list are replaced by TYF\'s defaults. Entries keep their category names.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(categoriesProvider.notifier).resetDefaults(kind);
    }
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.monthPaise,
    required this.monthCount,
    required this.onTap,
  });
  final CategoryOption category;
  final int monthPaise;
  final int monthCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subs = category.subcategories;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge.emoji(category.emoji, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (monthCount > 0)
                      Text(
                        Money.format(monthPaise),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                  ],
                ),
                Text(
                  monthCount == 0
                      ? 'Nothing this month'
                      : '$monthCount ${monthCount == 1 ? 'entry' : 'entries'} this month',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (subs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in subs.take(4)) _MiniChip(s),
                      if (subs.length > 4) _MiniChip('+${subs.length - 4}'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
