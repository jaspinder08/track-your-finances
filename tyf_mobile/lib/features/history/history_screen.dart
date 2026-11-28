import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_theme.dart';
import '../../core/design/design.dart';
import '../../core/utils/money.dart';
import '../accounts/account_balances.dart';
import '../transactions/screens/add_transaction_screen.dart';
import '../categories/data/category_repository.dart';
import '../transactions/data/entry_repository.dart';
import '../transactions/data/transaction_options.dart';
import '../transactions/widgets/swipe_entry.dart';
import '../../core/design/app_icons.dart';
import '../../core/widgets/inner_app_bar.dart';

/// What the History list is narrowed to.
@immutable
class HistoryFilter {
  const HistoryFilter({
    this.query = '',
    this.type,
    this.category,
    this.account,
  });
  final String query;
  final EntryType? type;
  final String? category;
  final String? account;

  bool get isEmpty =>
      query.isEmpty && type == null && category == null && account == null;

  /// True if [e] should be listed.
  bool matches(Entry e) {
    if (e.isDeleted || e.type == EntryType.goal) return false;
    if (type != null && e.type != type) return false;
    if (category != null && e.data.category != category) return false;
    if (account != null && !entryTouches(e, account!)) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final d = e.data;
    final digits = q.replaceAll(RegExp(r'[₹,\s]'), '');
    return [
          d.name,
          d.description,
          d.category,
          d.subcategory,
          d.paymentMethod,
          d.fromAccount,
          d.toAccount,
        ].any((f) => f != null && f.toLowerCase().contains(q)) ||
        (digits.isNotEmpty &&
            RegExp(r'^\d+$').hasMatch(digits) &&
            (e.amountPaise ~/ 100).toString().contains(digits));
  }
}

/// Entries matching [f], newest first, grouped by day.
List<(DateTime, List<Entry>)> groupByDay(List<Entry> all, HistoryFilter f) {
  final list = all.where(f.matches).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final groups = <(DateTime, List<Entry>)>[];
  for (final e in list) {
    final day = DateUtils.dateOnly(e.date);
    if (groups.isEmpty || groups.last.$1 != day) groups.add((day, []));
    groups.last.$2.add(e);
  }
  return groups;
}

/// Every transaction in one list, with search and filters.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({
    super.key,
    this.account,
    this.category,
    this.asTab = false,
  });

  /// Opens already filtered to this category (from Analytics).
  final String? category;

  /// Shown as a main tab: no app bar, room for the floating nav bar.
  final bool asTab;

  /// Opens already filtered to this account (from the Accounts page).
  final String? account;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  late var _filter = HistoryFilter(
    account: widget.account,
    category: widget.category,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set({
    String? query,
    EntryType? type,
    String? category,
    bool clearType = false,
    bool clearCategory = false,
  }) => setState(
    () => _filter = HistoryFilter(
      query: query ?? _filter.query,
      type: clearType ? null : (type ?? _filter.type),
      category: clearCategory ? null : (category ?? _filter.category),
      account: _filter.account,
    ),
  );

  Future<void> _pickCategory() async {
    final cats = ref.read(categorySetProvider);
    final options = [
      if (_filter.type != EntryType.income) ...cats.expense,
      if (_filter.type != EntryType.expense) ...cats.income,
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(c).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final o in {for (final o in options) o.name: o}.values)
              ListTile(
                leading: CategoryTile(name: o.name, glyph: o.emoji, size: 36),
                title: Text(o.name),
                trailing: o.name == _filter.category
                    ? const Icon(AppIcons.checkRounded)
                    : null,
                onTap: () => Navigator.pop(c, o.name),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _set(category: picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = ref.watch(entriesProvider).value ?? const <Entry>[];
    final groups = groupByDay(entries, _filter);
    final list = groups.expand((g) => g.$2).toList();
    final filtersOn = _filter.category != null || _filter.account != null;

    Widget typePill(String label, EntryType? t, IconData? icon, Color c) {
      final sel = _filter.type == t;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: sel ? scheme.primary : scheme.cardFill(0.7),
          shape: StadiumBorder(
            side: BorderSide(
              color: sel
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () =>
                _set(type: t, clearType: t == null, clearCategory: true),
            child: Padding(
              padding: EdgeInsets.fromLTRB(icon == null ? 18 : 5, 5, 14, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (sel ? scheme.onPrimary : c).withValues(
                          alpha: 0.2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 14,
                        color: sel ? scheme.onPrimary : c,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: sel ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final body = CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => _set(query: v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search transactions…',
                      filled: true,
                      fillColor: scheme.isLight ? Colors.white : null,
                      prefixIcon: const Icon(AppIcons.searchRounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide(color: scheme.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide(color: scheme.primary),
                      ),
                      suffixIcon: _filter.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(AppIcons.close),
                              onPressed: () {
                                _search.clear();
                                _set(query: '');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: filtersOn,
                  smallSize: 10,
                  backgroundColor: scheme.primary,
                  child: IconButton.filledTonal(
                    tooltip: 'Filter by category',
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                      fixedSize: const Size(56, 56),
                      backgroundColor: scheme.cardFill(0.8),
                      side: scheme.isLight
                          ? BorderSide(color: scheme.cardBorder)
                          : null,
                    ),
                    onPressed: _filter.type == EntryType.transfer
                        ? null
                        : _pickCategory,
                    icon: const Icon(AppIcons.tuneRounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                typePill('All', null, null, scheme.primary),
                typePill(
                  'Expenses',
                  EntryType.expense,
                  AppIcons.arrowDownwardRounded,
                  FinanceColors.expenseOf(context),
                ),
                typePill(
                  'Income',
                  EntryType.income,
                  AppIcons.arrowUpwardRounded,
                  FinanceColors.incomeOf(context),
                ),
                typePill(
                  'Transfers',
                  EntryType.transfer,
                  AppIcons.swapHorizRounded,
                  scheme.primary,
                ),
              ],
            ),
          ),
        ),
        // Active filters (category / account), each removable.
        if (filtersOn)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_filter.category != null)
                    InputChip(
                      label: Text(_filter.category!),
                      onDeleted: () => _set(clearCategory: true),
                    ),
                  if (_filter.account != null)
                    InputChip(
                      avatar: Icon(
                        accountIcons[_filter.account] ??
                            AppIcons.accountBalanceOutlined,
                        size: 18,
                      ),
                      label: Text(_filter.account!),
                      onDeleted: () => setState(
                        () => _filter = HistoryFilter(
                          query: _filter.query,
                          type: _filter.type,
                          category: _filter.category,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _filter.isEmpty ? 'Recent' : 'Results',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (list.isEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 360,
              child: EmptyState(
                emoji: _filter.isEmpty ? '🧾' : '🔍',
                title: _filter.isEmpty
                    ? 'No transactions yet'
                    : 'Nothing matches',
                message: _filter.isEmpty
                    ? 'Tap + to add your first one.'
                    : 'Try another word or clear the filters.',
              ),
            ),
          )
        else ...[
          for (final (day, dayEntries) in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      _dayLabel(day).toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    if (_daySpend(dayEntries) > 0)
                      Text(
                        '−${Money.format(_daySpend(dayEntries))}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: scheme.cardFill(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.cardBorder),
                    boxShadow: scheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < dayEntries.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 72,
                            color: scheme.cardBorder,
                          ),
                        SwipeEntry(
                          entry: dayEntries[i],
                          child: _TxCard(entry: dayEntries[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: widget.asTab ? 120 : 32)),
        ],
      ],
    );
    if (widget.asTab) return body;
    return Scaffold(
      appBar: const InnerAppBar(title: Text('All transactions')),
      body: body,
    );
  }

  static String _dayLabel(DateTime d) {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 0) return DateFormat('EEE, d MMM').format(d);
    return d.year == today.year
        ? DateFormat('EEE, d MMM').format(d)
        : DateFormat('EEE, d MMM y').format(d);
  }
}

/// A transaction as a card: category tile, name, details, amount
/// with a type tag, and a ⋮ menu (edit, duplicate, delete).
class _TxCard extends ConsumerWidget {
  const _TxCard({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final d = entry.data;
    final glyph = ref.watch(categorySetProvider).emojiFor(d.category);
    final details = [
      if (entry.type == EntryType.transfer)
        '${d.fromAccount ?? '?'} → ${d.toAccount ?? '?'}'
      else if (d.category != null && d.category != entry.title)
        d.category,
      if (d.subcategory != null) d.subcategory,
      if (d.paymentMethod != null) d.paymentMethod,
    ].join(' • ');

    final (sign, typeColor, _) = switch (entry.type) {
      EntryType.income => ('+', FinanceColors.incomeOf(context), 'Income'),
      EntryType.expense => ('−', FinanceColors.expenseOf(context), 'Expense'),
      EntryType.goal => ('', const Color(0xFF8B5CF6), 'Goal'),
      _ => ('', scheme.primary, 'Transfer'),
    };

    // One neutral surface for every transaction, matching the rest of the
    // theme; colour lives only on the amount and the small type marker.
    final amountColor = entry.type == EntryType.expense
        ? scheme.onSurface
        : typeColor;

    return Material(
      color: scheme.isLight ? Colors.white : scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => showAddTransactionScreen(context, editing: entry),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  glyph != null
                      ? CategoryTile(name: d.category, glyph: glyph, size: 46)
                      : Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            color: typeColor.withValues(alpha: 0.15),
                          ),
                          child: Icon(entry.type.icon, color: typeColor),
                        ),
                  // Type marker: a small arrow badge on the tile's corner.
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: typeColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? scheme.surfaceContainerHigh
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        entry.type.icon,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${Money.format(entry.amountPaise)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: Icon(
                  AppIcons.moreVertRounded,
                  color: scheme.onSurfaceVariant,
                ),
                onSelected: (v) => switch (v) {
                  'edit' => showAddTransactionScreen(context, editing: entry),
                  'copy' => duplicateEntry(context, ref, entry),
                  _ => deleteEntry(context, ref, entry),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'copy',
                    child: Text('Duplicate to today'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Total spent on a day (expenses only).
int _daySpend(List<Entry> entries) => entries
    .where((e) => e.type == EntryType.expense)
    .fold(0, (sum, e) => sum + e.amountPaise);
