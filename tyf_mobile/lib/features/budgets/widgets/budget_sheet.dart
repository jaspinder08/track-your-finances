import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../transactions/data/transaction_options.dart';
import '../../categories/data/category_repository.dart';
import '../data/budget_repository.dart';
import 'budget_progress_bar.dart';
import '../../../core/design/app_icons.dart';

/// Opens the "Set budget" sheet. Pass [category] to edit that budget
/// (or start a new one with that category already picked).
Future<void> showBudgetSheet(BuildContext context, {String? category}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => BudgetSheet(initialCategory: category),
  );
  if (message != null) {
    messenger.showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }
}

class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  CategoryOption? _category;
  bool _alert = true;
  bool _showCategoryError = false;
  bool _saving = false;

  static const _quick = [100000, 200000, 500000, 1000000, 2000000];

  CategoryBudget? _existing(String? name) =>
      (ref.read(budgetsProvider).value ?? const <CategoryBudget>[])
          .where((b) => b.category == name)
          .firstOrNull;

  bool get _isEditing => _existing(_category?.name) != null;

  @override
  void initState() {
    super.initState();
    final c = ref
        .read(categorySetProvider)
        .expense
        .where((c) => c.name == widget.initialCategory)
        .firstOrNull;
    if (c != null) _pick(c, initial: true);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Picking a category that already has a budget loads its values.
  void _pick(CategoryOption c, {bool initial = false}) {
    void apply() {
      _category = c;
      _showCategoryError = false;
      final b = _existing(c.name);
      if (b != null) {
        _amount.text = '${b.limitPaise ~/ 100}';
        _alert = b.alertAt80;
      }
    }

    initial ? apply() : setState(apply);
  }

  void _setAmount(int paise) => setState(() {
    _amount.text = '${paise ~/ 100}';
    _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
  });

  Future<void> _save() async {
    final validForm = _formKey.currentState!.validate();
    if (_category == null) setState(() => _showCategoryError = true);
    if (!validForm || _category == null || _saving) return;
    setState(() => _saving = true);
    final limit = parsePaise(_amount.text)!;
    final wasEditing = _isEditing;
    try {
      await ref
          .read(budgetsProvider.notifier)
          .save(
            CategoryBudget(
              category: _category!.name,
              limitPaise: limit,
              alertAt80: _alert,
            ),
          );
      if (mounted) {
        Navigator.pop(
          context,
          '${_category!.name} budget ${wasEditing ? 'updated' : 'set'} to '
          '${Money.format(limit)}/month',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t save. Please try again.')),
        );
      }
    }
  }

  Future<void> _remove() async {
    final name = _category!.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $name budget?'),
        content: const Text(
          'Your expenses stay. Only the monthly limit is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(budgetsProvider.notifier).remove(name);
    if (mounted) Navigator.pop(context, '$name budget removed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final budgets = ref.watch(budgetsProvider).value ?? const [];
    final spend = ref.watch(monthSpendProvider);
    final lastMonth = ref.watch(lastMonthSpendProvider);
    final limit = parsePaise(_amount.text);
    final spent = spend[_category?.name] ?? 0;
    final suggestion = lastMonth[_category?.name];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: category avatar, title, Save.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, a) =>
                        ScaleTransition(scale: a, child: child),
                    child: Container(
                      key: ValueKey(_category?.name),
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: _category == null
                          ? Icon(
                              AppIcons.pieChartRounded,
                              color: scheme.primary,
                            )
                          : Text(
                              _category!.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit budget' : 'New budget',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          _category == null
                              ? 'Monthly limit'
                              : '${_category!.name} · every month',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(AppIcons.checkRounded, size: 18),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(context, 'Category'),
                    _CategoryGrid(
                      categories: ref.watch(categorySetProvider).expense,
                      selected: _category,
                      budgets: budgets,
                      onPick: _pick,
                    ),
                    if (_showCategoryError)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 8),
                        child: Text(
                          'Pick a category',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _label(context, 'Monthly limit'),
                    _LimitField(
                      controller: _amount,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (suggestion != null && suggestion > 0) ...[
                            ActionChip(
                              avatar: Icon(
                                AppIcons.autoAwesomeRounded,
                                size: 16,
                                color: scheme.primary,
                              ),
                              label: Text(
                                'Last month ${Money.format(suggestion)}',
                              ),
                              onPressed: () =>
                                  _setAmount((suggestion + 99) ~/ 100 * 100),
                            ),
                            const SizedBox(width: 8),
                          ],
                          for (final q in _quick) ...[
                            ChoiceChip(
                              label: Text(
                                Money.compact(q).replaceAll('.0', ''),
                              ),
                              selected: limit == q,
                              onSelected: (_) => _setAmount(q),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      alignment: Alignment.topCenter,
                      child: _category != null && limit != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: _Preview(spent: spent, limit: limit),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _alert,
                      onChanged: (v) => setState(() => _alert = v),
                      secondary: Icon(
                        AppIcons.notificationsActiveOutlined,
                        color: scheme.primary,
                      ),
                      title: const Text('Warn me at 80%'),
                      subtitle: const Text(
                        'Highlight this budget when it\'s nearly used up',
                      ),
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                        onPressed: _remove,
                        icon: const Icon(AppIcons.deleteOutline),
                        label: const Text('Remove budget'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _LimitField extends StatelessWidget {
  const _LimitField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleLarge?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      style: style,
      decoration: InputDecoration(
        labelText: 'Amount per month',
        hintText: '0',
        suffixText: '/ month',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Text('₹', style: style),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      validator: (v) =>
          parsePaise(v ?? '') == null ? 'Enter a limit, e.g. 5000' : null,
    );
  }
}

/// Emoji tiles, 4 per row. Categories that already have a budget show
/// their limit under the name.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.budgets,
    required this.onPick,
  });
  final CategoryOption? selected;
  final List<CategoryBudget> budgets;
  final ValueChanged<CategoryOption> onPick;
  final List<CategoryOption> categories;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        final w = (box.maxWidth - gap * 3) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in categories)
              Builder(
                builder: (context) {
                  final isSel = c == selected;
                  final b = budgets
                      .where((b) => b.category == c.name)
                      .firstOrNull;
                  return Semantics(
                    button: true,
                    selected: isSel,
                    label: c.name,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onPick(c),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: w,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? scheme.primary.withValues(alpha: 0.12)
                              : scheme.surfaceContainerHighest.withValues(
                                  alpha: 0.45,
                                ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? scheme.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            AnimatedScale(
                              scale: isSel ? 1.15 : 1,
                              duration: const Duration(milliseconds: 180),
                              child: Text(
                                c.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSel
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                            ),
                            SizedBox(
                              height: 14,
                              child: b == null
                                  ? null
                                  : Text(
                                      Money.compact(
                                        b.limitPaise,
                                      ).replaceAll('.0', ''),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.primary,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// "This month so far" card shown once a category and limit are set.
class _Preview extends StatelessWidget {
  const _Preview({required this.spent, required this.limit});
  final int spent;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = spent / limit;
    final color = budgetColor(context, ratio);
    final left = limit - spent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'This month so far',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${(ratio * 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          BudgetProgressBar(ratio: ratio, color: color),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: Money.format(spent),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' of ${Money.format(limit)} spent · '),
                TextSpan(
                  text: left >= 0
                      ? '${Money.format(left)} left'
                      : '${Money.format(-left)} over',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
