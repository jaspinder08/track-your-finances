import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_theme.dart';
import '../../core/design/design.dart';
import '../../core/utils/money.dart';
import '../accounts/account_balances.dart';
import '../calendar/widgets/day_entries_sheet.dart' show EntryTile;
import '../categories/data/category_repository.dart';
import '../transactions/data/entry.dart';
import '../transactions/data/entry_repository.dart';
import '../transactions/data/transaction_options.dart';
import '../transactions/widgets/swipe_entry.dart';

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
  const HistoryScreen({super.key, this.account});

  /// Opens already filtered to this account (from the Accounts page).
  final String? account;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  late var _filter = HistoryFilter(account: widget.account);

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
                leading: Text(o.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(o.name),
                trailing: o.name == _filter.category
                    ? const Icon(Icons.check_rounded)
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
    final shown = groups.fold(0, (s, g) => s + g.$2.length);
    final spent = groups
        .expand((g) => g.$2)
        .where((e) => e.type == EntryType.expense)
        .fold(0, (s, e) => s + e.amountPaise);
    final earned = groups
        .expand((g) => g.$2)
        .where((e) => e.type == EntryType.income)
        .fold(0, (s, e) => s + e.amountPaise);

    Widget typeChip(String label, EntryType? t) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        showCheckmark: false,
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          color: _filter.type == t ? scheme.onPrimary : scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        selected: _filter.type == t,
        onSelected: (_) =>
            _set(type: t, clearType: t == null, clearCategory: true),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('All transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (v) => _set(query: v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search name, category, amount…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _filter.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _set(query: '');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_filter.account != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      avatar: Icon(
                        accountIcons[_filter.account] ??
                            Icons.account_balance_outlined,
                        size: 18,
                      ),
                      label: Text(_filter.account!),
                      selected: true,
                      onDeleted: () => setState(
                        () => _filter = HistoryFilter(
                          query: _filter.query,
                          type: _filter.type,
                          category: _filter.category,
                        ),
                      ),
                    ),
                  ),
                typeChip('All', null),
                typeChip('Expenses', EntryType.expense),
                typeChip('Income', EntryType.income),
                typeChip('Transfers', EntryType.transfer),
                if (_filter.type != EntryType.transfer)
                  InputChip(
                    avatar: const Icon(Icons.grid_view_rounded, size: 18),
                    label: Text(_filter.category ?? 'Category'),
                    selected: _filter.category != null,
                    onPressed: _pickCategory,
                    onDeleted: _filter.category == null
                        ? null
                        : () => _set(clearCategory: true),
                  ),
              ],
            ),
          ),
          // What the current list adds up to.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Text(
                  '$shown ${shown == 1 ? 'transaction' : 'transactions'}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (earned > 0)
                  Text(
                    '+${Money.format(earned)}  ',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: FinanceColors.income,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (spent > 0)
                  Text(
                    '−${Money.format(spent)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: FinanceColors.expense,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? EmptyState(
                    emoji: _filter.isEmpty ? '🧾' : '🔍',
                    title: _filter.isEmpty
                        ? 'No transactions yet'
                        : 'Nothing matches',
                    message: _filter.isEmpty
                        ? 'Tap + to add your first one.'
                        : 'Try another word or clear the filters.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final (day, list) = groups[i];
                      final net = list.fold(0, (s, e) => s + e.balanceEffect);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                            child: Row(
                              children: [
                                Text(
                                  _dayLabel(day),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                if (net != 0)
                                  Text(
                                    '${net < 0 ? '−' : '+'}${Money.format(net.abs())}',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          for (final e in list)
                            SwipeEntry(
                              entry: e,
                              child: EntryTile(entry: e),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
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
