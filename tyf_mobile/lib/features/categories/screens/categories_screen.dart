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
    appBar: AppBar(
      leadingWidth: 72,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: IconButton.filledTonal(
            tooltip: 'Back',
            style: IconButton.styleFrom(shape: const CircleBorder()),
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(AppIcons.arrowBackRounded),
          ),
        ),
      ),
      title: const Text('Categories'),
    ),
    floatingActionButton: FloatingActionButton(
      heroTag: 'new-category',
      tooltip: 'New category',
      onPressed: () =>
          showCategoryEditor(context, kind: ref.read(categoryKindViewProvider)),
      shape: const CircleBorder(),
      child: const Icon(AppIcons.addRounded, size: 28),
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
          child: _KindSwitch(
            kind: kind,
            onChanged: (k) =>
                ref.read(categoryKindViewProvider.notifier).set(k),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
          child: Row(
            children: [
              Icon(
                AppIcons.gridViewRounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${list.length} categories  •  Hold and drag to reorder',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ),
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
                    index: i,
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

/// One category: a glowing colour tile, name, this month's spend in a
/// pill and its share as a bar. Tap to open sub-categories and Edit.
class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.index,
    required this.category,
    required this.monthPaise,
    required this.monthCount,
    required this.share,
    required this.onEdit,
  });
  final int index;
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
    final active = n > 0;
    final details = [
      active ? '$n ${n == 1 ? 'entry' : 'entries'}' : 'Nothing this month',
      if (subs.isNotEmpty)
        '${subs.length} ${subs.length == 1 ? 'sub-category' : 'sub-categories'}',
    ].join('  •  ');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Categories with spending this month stand out: tinted, with an
        // accent edge.
        gradient: LinearGradient(
          colors: [
            active
                ? Color.lerp(scheme.surfaceContainerHigh, scheme.primary, 0.16)!
                : scheme.surfaceContainerHigh.withValues(alpha: 0.7),
            scheme.surfaceContainerHigh.withValues(alpha: 0.7),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Stack(
            children: [
              // Accent edge for categories with spending this month.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 4 : 0,
                  color: scheme.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CategoryTile(name: c.name, glyph: c.emoji, size: 56),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(fontSize: 17),
                                    ),
                                  ),
                                  if (active)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                      ),
                                      child: Text(
                                        Money.format(widget.monthPaise),
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                details,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (active) ...[
                                const SizedBox(height: 10),
                                BudgetProgressBar(
                                  ratio: widget.share,
                                  color: scheme.primary,
                                  height: 5,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: _open ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            AppIcons.chevronRightRounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: !_open
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(left: 70, top: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (subs.isEmpty)
                                    Text(
                                      'No sub-categories yet',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final s in subs) _MiniChip(s),
                                      ],
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
                                      icon: const Icon(
                                        AppIcons.editOutlined,
                                        size: 18,
                                      ),
                                      label: Text('Edit ${c.name}'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expense | Income as a pill with a sliding accent thumb.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.kind, required this.onChanged});
  final CategoryKind kind;
  final ValueChanged<CategoryKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isExpense = kind == CategoryKind.expense;

    Widget side(CategoryKind k, IconData icon, String label) {
      final sel = k == kind;
      return Expanded(
        child: Semantics(
          selected: sel,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: () => onChanged(k),
            child: SizedBox(
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: sel ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: sel ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: isExpense ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      Color.lerp(scheme.primary, Colors.white, 0.12)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              side(CategoryKind.expense, AppIcons.northEastRounded, 'Expense'),
              side(CategoryKind.income, AppIcons.southWestRounded, 'Income'),
            ],
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
