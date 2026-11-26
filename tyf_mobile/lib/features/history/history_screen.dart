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
    final spent = list
        .where((e) => e.type == EntryType.expense)
        .fold(0, (s, e) => s + e.amountPaise);
    final earned = list
        .where((e) => e.type == EntryType.income)
        .fold(0, (s, e) => s + e.amountPaise);
    final net = earned - spent;
    final filtersOn = _filter.category != null || _filter.account != null;

    Widget typePill(String label, EntryType? t, IconData? icon, Color c) {
      final sel = _filter.type == t;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: sel
              ? scheme.primary
              : scheme.surfaceContainerHigh.withValues(alpha: 0.7),
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
                      prefixIcon: const Icon(AppIcons.searchRounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.25),
                        ),
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
                      backgroundColor: scheme.surfaceContainerHigh.withValues(
                        alpha: 0.8,
                      ),
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
                  FinanceColors.expense,
                ),
                typePill(
                  'Income',
                  EntryType.income,
                  AppIcons.arrowUpwardRounded,
                  FinanceColors.income,
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _TotalCard(
                  label: 'Income',
                  paise: earned,
                  icon: AppIcons.arrowUpwardRounded,
                  color: FinanceColors.income,
                ),
                const SizedBox(width: 8),
                _TotalCard(
                  label: 'Expenses',
                  paise: spent,
                  icon: AppIcons.arrowDownwardRounded,
                  color: FinanceColors.expense,
                ),
                const SizedBox(width: 8),
                _TotalCard(
                  label: 'Net',
                  paise: net,
                  icon: AppIcons.barChartRounded,
                  color: scheme.primary,
                  signed: true,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _filter.isEmpty ? 'Recent Transactions' : 'Results',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${list.length} ${list.length == 1 ? 'transaction' : 'transactions'}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
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
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, widget.asTab ? 120 : 32),
            sliver: SliverList.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => SwipeEntry(
                entry: list[i],
                child: _TxCard(
                  entry: list[i],
                  date: _dayLabel(DateUtils.dateOnly(list[i].date)),
                ),
              ),
            ),
          ),
      ],
    );
    if (widget.asTab) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('All transactions')),
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

/// One of the three totals for what's listed.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.paise,
    required this.icon,
    required this.color,
    this.signed = false,
  });
  final String label;
  final int paise;
  final IconData icon;
  final Color color;

  /// Shows − and colours red when negative (net balance).
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final negative = signed && paise < 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.16),
              scheme.surfaceContainerHigh.withValues(alpha: 0.6),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.2),
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${negative ? '−' : ''}${Money.format(paise.abs())}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: negative ? const Color(0xFFFF8A92) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A transaction as a card: category tile, name, details, date, amount
/// with a type tag, and a ⋮ menu (edit, duplicate, delete).
class _TxCard extends ConsumerWidget {
  const _TxCard({required this.entry, required this.date});
  final Entry entry;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
    final (sign, color, tag) = switch (entry.type) {
      EntryType.income => ('+', FinanceColors.income, 'Income'),
      EntryType.expense => ('−', const Color(0xFFFF6B78), 'Expense'),
      _ => ('', scheme.primary, 'Transfer'),
    };

    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAddTransactionScreen(context, editing: entry),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
          child: Row(
            children: [
              glyph != null
                  ? CategoryTile(name: d.category, glyph: glyph, size: 52)
                  : Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary.withValues(alpha: 0.9),
                            Color.lerp(scheme.primary, Colors.black, 0.35)!,
                          ],
                        ),
                      ),
                      child: Icon(entry.type.icon, color: Colors.white),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Color.lerp(
                            scheme.onSurfaceVariant,
                            scheme.primary,
                            0.35,
                          ),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          AppIcons.scheduleRounded,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          date,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${Money.format(entry.amountPaise)}',
                    style: theme.textTheme.titleMedium?.copyWith(color: color),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      tag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Color.lerp(color, Colors.white, 0.3),
                      ),
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
