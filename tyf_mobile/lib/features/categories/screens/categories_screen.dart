import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../budgets/widgets/budget_progress_bar.dart';
import '../../../core/utils/money.dart';
import '../../transactions/data/entry.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';
import '../data/category_repository.dart';
import '../widgets/category_editor_sheet.dart';
import '../../../core/design/app_icons.dart';

/// Which list (expense or income) the Categories page shows.
final categoryKindViewProvider =
    NotifierProvider<CategoryKindView, CategoryKind>(CategoryKindView.new);

class CategoryKindView extends Notifier<CategoryKind> {
  @override
  CategoryKind build() => CategoryKind.expense;
  void set(CategoryKind k) => state = k;
}

/// Categories page (from Budgets › Manage categories, or the sidebar).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Categories')),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'new-category',
      tooltip: 'New category',
      onPressed: () =>
          showCategoryEditor(context, kind: ref.read(categoryKindViewProvider)),
      icon: const Icon(AppIcons.addRounded),
      label: const Text('New category'),
    ),
    body: const CategoriesView(),
  );
}

/// Expense/income category lists. Tap to open, drag to reorder.
class CategoriesView extends ConsumerWidget {
  const CategoriesView({super.key});

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
                  icon: Icon(AppIcons.northEastRounded),
                  label: Text('Expense'),
                ),
                ButtonSegment(
                  value: CategoryKind.income,
                  icon: Icon(AppIcons.southWestRounded),
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
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              96,
            ), // clear of the button
            itemCount: list.length,
            buildDefaultDragHandles: false,
            onReorder: (from, to) =>
                ref.read(categoriesProvider.notifier).reorder(kind, from, to),
            proxyDecorator: (child, _, _) =>
                Material(color: Colors.transparent, elevation: 6, child: child),
            itemBuilder: (context, i) {
              final c = list[i];
              final s = stats[c.name];
              final kindTotal = list.fold(
                0,
                (t, o) => t + (stats[o.name]?.$1 ?? 0),
              );
              return Padding(
                key: ValueKey('${kind.name}-${c.name}'),
                padding: const EdgeInsets.only(bottom: 10),
                child: ReorderableDelayedDragStartListener(
                  index: i,
                  child: _CategoryCard(
                    category: c,
                    monthPaise: s?.$1 ?? 0,
                    monthCount: s?.$2 ?? 0,
                    share: kindTotal == 0 ? 0 : (s?.$1 ?? 0) / kindTotal,
                    onEdit: () =>
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

/// One category: emoji, name, this month's spend and its share of the
/// month. Tap to open it and see its sub-categories and Edit.
class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.category,
    required this.monthPaise,
    required this.monthCount,
    required this.share,
    required this.onEdit,
  });
  final CategoryOption category;
  final int monthPaise;
  final int monthCount;

  /// 0..1 of everything in this list this month.
  final double share;
  final VoidCallback onEdit;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = widget.category;
    final subs = c.subcategories;
    final n = widget.monthCount;
    final details = [
      n == 0
          ? 'Nothing this month'
          : subs.isEmpty
          ? '$n ${n == 1 ? 'entry' : 'entries'} this month'
          : '$n ${n == 1 ? 'entry' : 'entries'}',
      if (subs.isNotEmpty)
        '${subs.length} ${subs.length == 1 ? 'sub-category' : 'sub-categories'}',
    ].join(' · ');

    return AppCard(
      onTap: () => setState(() => _open = !_open),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge.emoji(c.emoji, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (n > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    Money.format(widget.monthPaise),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  AppIcons.expandMoreRounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // Share of this month's total, as a thin bar.
          if (n > 0) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 56, right: 6),
              child: BudgetProgressBar(
                ratio: widget.share,
                color: scheme.primary,
                height: 5,
              ),
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(left: 56, top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (subs.isEmpty)
                          Text(
                            'No sub-categories yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [for (final s in subs) _MiniChip(s)],
                          ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: widget.onEdit,
                            icon: const Icon(AppIcons.editOutlined, size: 18),
                            label: Text('Edit ${c.name}'),
                          ),
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
