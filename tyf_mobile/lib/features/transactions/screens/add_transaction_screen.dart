import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/design.dart';
import '../../../core/navigation/page_route.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/date_sheet.dart';
import '../../categories/data/category_repository.dart';
import '../data/entry.dart';
import '../data/entry_repository.dart';
import '../data/transaction_options.dart';

export '../data/entry.dart';

/// Opens the full-screen "Add a transaction" page. Pass [initialType] or
/// [initialDate] to pre-fill (e.g. tapping a calendar day opens it on that
/// date). Pass [editing] to change an existing entry instead.
///
/// A full screen that slides in like the app's other pages; it settles
/// first and the keyboard opens after, so nothing jumps or resizes.
/// Returns the last draft saved, or null if closed without saving.
Future<EntryDraft?> showAddTransactionScreen(
  BuildContext context, {
  EntryType initialType = EntryType.expense,
  DateTime? initialDate,
  Entry? editing,
  String? initialCategory,
}) {
  return Navigator.of(context).push<EntryDraft>(
    appPageRoute(
      AddTransactionScreen(
        initialType: initialType,
        initialDate: initialDate,
        editing: editing,
        initialCategory: initialCategory,
      ),
    ),
  );
}

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.initialType = EntryType.expense,
    this.initialDate,
    this.editing,
    this.initialCategory,
  });

  final EntryType initialType;
  final DateTime? initialDate;

  /// Category to pre-select when adding (ignored if it doesn't exist for
  /// the entry type).
  final String? initialCategory;

  /// The entry being edited; null when adding.
  final Entry? editing;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _savedSoFar = TextEditingController();

  late EntryType _type = widget.editing?.type ?? widget.initialType;
  late DateTime _date = DateUtils.dateOnly(
    widget.editing?.date ?? widget.initialDate ?? DateTime.now(),
  );
  CategoryOption? _category;
  String? _subcategory;
  String _paymentMethod = paymentMethods.first;
  String? _fromAccount;
  String? _toAccount;
  bool _recurring = false;
  int _repeatEvery = 1;
  RepeatUnit _repeatUnit = RepeatUnit.month;
  bool _showMore = false;
  bool _saving = false;

  /// The accent picked in Settings → Appearance.
  Color get _accent => Theme.of(context).colorScheme.primary;

  bool get _isMoneyFlow =>
      _type == EntryType.expense || _type == EntryType.income;

  bool get _isEditing => widget.editing != null;

  bool get _isGoal => _type == EntryType.goal;

  @override
  void initState() {
    super.initState();
    final d = widget.editing?.data;
    if (d == null) {
      final pick = widget.initialCategory;
      if (pick != null) {
        final set = ref.read(categorySetProvider);
        final cats = _type == EntryType.income ? set.income : set.expense;
        _category = cats.where((c) => c.name == pick).firstOrNull;
      }
      return;
    }
    _amount.text = _rupees(d.amountPaise);
    _name.text = d.name ?? '';
    _description.text = d.description ?? '';
    _showMore = _description.text.isNotEmpty;
    if (d.savedSoFarPaise != null) {
      _savedSoFar.text = _rupees(d.savedSoFarPaise!);
    }
    final set = ref.read(categorySetProvider);
    final cats = d.type == EntryType.income ? set.income : set.expense;
    _category = cats.where((c) => c.name == d.category).firstOrNull;
    if (_category?.subcategories.contains(d.subcategory) ?? false) {
      _subcategory = d.subcategory;
    }
    if (paymentMethods.contains(d.paymentMethod)) {
      _paymentMethod = d.paymentMethod!;
    }
    _fromAccount = d.fromAccount;
    _toAccount = d.toAccount;
    if (d.repeat != null) {
      _recurring = true;
      _repeatEvery = d.repeat!.every;
      _repeatUnit = d.repeat!.unit;
    }
  }

  bool _focusScheduled = false;

  /// Opens the keyboard only once the page has finished sliding in, so the
  /// slide and the keyboard never animate at the same time.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusScheduled || _isEditing) return;
    _focusScheduled = true;
    final animation = ModalRoute.of(context)?.animation;
    void focus() {
      if (mounted) _amountFocus.requestFocus();
    }

    if (animation == null || animation.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => focus());
    } else {
      void listener(AnimationStatus s) {
        if (s == AnimationStatus.completed) {
          animation.removeStatusListener(listener);
          focus();
        }
      }

      animation.addStatusListener(listener);
    }
  }

  /// 25050 paise -> "250.50"; 25000 -> "250".
  static String _rupees(int paise) => paise % 100 == 0
      ? '${paise ~/ 100}'
      : '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    _name.dispose();
    _description.dispose();
    _savedSoFar.dispose();
    super.dispose();
  }

  void _changeType(EntryType type) {
    if (type == _type) return;
    setState(() {
      // Categories differ between income and expense, so clear them.
      _type = type;
      _category = null;
      _subcategory = null;
    });
  }

  EntryDraft _draft() {
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return EntryDraft(
      type: _type,
      amountPaise: parsePaise(_amount.text)!,
      date: _date,
      name: text(_name),
      description: text(_description),
      category: _isMoneyFlow ? _category?.name : null,
      subcategory: _isMoneyFlow ? _subcategory : null,
      paymentMethod: _isMoneyFlow ? _paymentMethod : null,
      fromAccount: _type == EntryType.transfer ? _fromAccount : null,
      toAccount: _type == EntryType.transfer ? _toAccount : null,
      repeat: _isMoneyFlow && _recurring
          ? Repeat(every: _repeatEvery, unit: _repeatUnit)
          : null,
      savedSoFarPaise: _type == EntryType.goal
          ? parsePaise(_savedSoFar.text)
          : null,
    );
  }

  /// Validates and saves. With [another], clears the form and stays open.
  Future<void> _save({bool another = false}) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final draft = _draft();
    final messenger = ScaffoldMessenger.of(context);
    final amount = Money.format(draft.amountPaise);
    String message;
    var ok = true;
    try {
      final n = ref.read(entriesProvider.notifier);
      if (_isEditing) {
        await n.edit(widget.editing!.id, draft);
        message = '${draft.type.label} of $amount updated';
      } else {
        await n.add(draft);
        message = '${draft.type.label} of $amount added';
      }
    } catch (_) {
      ok = false;
      message = 'Couldn\'t save. Please try again.';
    }
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    if (!ok) {
      setState(() => _saving = false);
      return;
    }
    if (another) {
      // Reset first (clears error messages), then empty the fields:
      // reset() restores each field to its last built value.
      _formKey.currentState!.reset();
      setState(() {
        _saving = false;
        _amount.clear();
        _name.clear();
        _description.clear();
        _savedSoFar.clear();
        _subcategory = null;
      });
      _amountFocus.requestFocus();
    } else {
      Navigator.pop(context, draft);
    }
  }

  String get _amountLabel => switch (_type) {
    EntryType.expense => 'Amount spent',
    EntryType.income => 'Amount received',
    EntryType.transfer => 'Amount to move',
    EntryType.goal => 'Target amount',
  };

  /// Roughly the Save bar's height, which the keyboard covers.
  static const _barHeight = 69.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      // The page doesn't shrink for the keyboard: the Save buttons stay at
      // the bottom of the screen, under the keyboard, and show again when
      // it closes. The list pads itself so fields still scroll into view.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Top bar: back, title, close.
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _isGoal
                            ? (_isEditing ? 'Edit goal' : 'New goal')
                            : _isEditing
                            ? 'Edit ${_type.label.toLowerCase()}'
                            : 'Add a transaction',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24 + math.max(0, keyboard - _barHeight),
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // Goals are made on the Goals page; the form opens
                    // straight in goal mode there, without the type pills.
                    if (!_isGoal) ...[
                      _TypeChips(selected: _type, onChanged: _changeType),
                      const SizedBox(height: 16),
                    ],
                    _heroCard(theme),
                    const SizedBox(height: 12),
                    ...switch (_type) {
                      EntryType.expense ||
                      EntryType.income => _moneyFlowCards(theme),
                      EntryType.transfer => [
                        _TransferCard(
                          from: _fromAccount,
                          to: _toAccount,
                          color: _accent,
                          onFrom: (a) => setState(() => _fromAccount = a),
                          onTo: (a) => setState(() => _toAccount = a),
                          onSwap: () => setState(() {
                            final f = _fromAccount;
                            _fromAccount = _toAccount;
                            _toAccount = f;
                          }),
                        ),
                      ],
                      EntryType.goal => _goalCards(theme),
                    },
                    const SizedBox(height: 12),
                    _notes(theme),
                  ],
                ),
              ),
              // Bottom bar: Save & add another · Save. Hidden while the
              // keyboard is up; fades in once it's gone.
              AnimatedOpacity(
                opacity: keyboard > 0 ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: keyboard > 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      border: Border(
                        top: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!_isEditing)
                              Flexible(
                                child: TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _save(another: true),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Save & add another',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                              ),
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: const Text('Save'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Big centred amount, then date and name rows.
  Widget _heroCard(ThemeData theme) {
    final scheme = theme.colorScheme;
    final big = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );
    final nameLabel = switch (_type) {
      EntryType.expense => 'Paid to',
      EntryType.income => 'Received from',
      EntryType.transfer => 'Note',
      EntryType.goal => 'Goal name',
    };
    final nameHint = switch (_type) {
      EntryType.expense => 'Name or place',
      EntryType.income => 'e.g. November salary',
      EntryType.transfer => 'Optional',
      EntryType.goal => 'e.g. New laptop',
    };
    final needsName = _type != EntryType.transfer;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          Text(
            _amountLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          _AmountInput(
            controller: _amount,
            focusNode: _amountFocus,
            style: big,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _Row(
                  label: _type == EntryType.goal ? 'Target date' : 'Date',
                  onTap: _pickDate,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dateText(),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.event_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
                _Row(
                  label: nameLabel,
                  trailing: Expanded(
                    child: TextFormField(
                      controller: _name,
                      textAlign: TextAlign.right,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 60,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        filled: false,
                        isDense: true,
                        counterText: '',
                        hintText: nameHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        errorStyle: const TextStyle(height: 0.8),
                      ),
                      validator: (v) =>
                          needsName && (v == null || v.trim().isEmpty)
                          ? (_type == EntryType.goal
                                ? 'Name your goal'
                                : 'Give it a name')
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateText() {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = _date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return DateFormat(
      _date.year == today.year ? 'EEE, d MMM' : 'd MMM y',
    ).format(_date);
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDateSheet(context, initial: _date);
    if (picked != null) setState(() => _date = picked);
  }

  List<Widget> _moneyFlowCards(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isExpense = _type == EntryType.expense;
    final subs = _category?.subcategories ?? const <String>[];
    final categories = isExpense
        ? ref.watch(categorySetProvider).expense
        : ref.watch(categorySetProvider).income;

    return [
      // Payment method + repeat, tinted with the accent.
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: isExpense ? 'Paid with' : 'Received via',
                  initialValue: _paymentMethod,
                  onSelected: (m) => setState(() => _paymentMethod = m),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  itemBuilder: (_) => [
                    for (final m in paymentMethods)
                      PopupMenuItem(
                        value: m,
                        child: Row(
                          children: [
                            Icon(paymentMethodIcons[m], size: 20),
                            const SizedBox(width: 12),
                            Text(m),
                          ],
                        ),
                      ),
                  ],
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          paymentMethodIcons[_paymentMethod],
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isExpense ? 'Paid with' : 'Received via',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _paymentMethod,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Repeat',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _recurring,
                  onChanged: (v) => setState(() => _recurring = v),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: !_recurring
                  ? const SizedBox(width: double.infinity)
                  : _RepeatRow(
                      isExpense: isExpense,
                      every: _repeatEvery,
                      unit: _repeatUnit,
                      onEvery: (n) => setState(() => _repeatEvery = n),
                      onUnit: (u) => setState(() => _repeatUnit = u),
                    ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Category: a row with +, or the chosen one; grid opens in a sheet.
      _CategoryField(
        key: ValueKey(_type),
        selected: _category,
        onTap: () async {
          FocusScope.of(context).unfocus();
          final c = await showModalBottomSheet<CategoryOption>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (ctx) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Choose a category',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  _CategoryPicker(
                    categories: categories,
                    selected: _category,
                    color: _accent,
                    onChanged: (c) => Navigator.pop(ctx, c),
                  ),
                ],
              ),
            ),
          );
          if (c != null && c != _category) {
            setState(() {
              _category = c;
              _subcategory = null;
            });
          }
        },
        subcategory: subs.isEmpty
            ? null
            : DropdownButtonFormField<String?>(
                // New key per category => the dropdown rebuilds empty
                // with that category's subcategories.
                key: ValueKey(_category!.name),
                value: _subcategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Subcategory (optional)',
                  prefixIcon: Icon(Icons.subdirectory_arrow_right_rounded),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  for (final s in subs)
                    DropdownMenuItem<String?>(value: s, child: Text(s)),
                ],
                onChanged: (s) => setState(() => _subcategory = s),
              ),
      ),
    ];
  }

  List<Widget> _goalCards(ThemeData theme) {
    final target = parsePaise(_amount.text);
    final saved = parsePaise(_savedSoFar.text) ?? 0;
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _savedSoFar,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Already saved (optional)',
                prefixIcon: Icon(Icons.savings_outlined),
                prefixText: '₹ ',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final s = parsePaise(v);
                if (s == null) return 'Enter a valid amount';
                if (target != null && s > target) {
                  return 'Can\'t be more than the target';
                }
                return null;
              },
            ),
            if (target != null && saved <= target) ...[
              const SizedBox(height: 16),
              _GoalProgress(saved: saved, target: target, color: _accent),
            ],
          ],
        ),
      ),
    ];
  }

  /// "•••" reveals the notes card; it starts open when editing a note.
  Widget _notes(ThemeData theme) {
    final scheme = theme.colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      alignment: Alignment.topCenter,
      child: !_showMore
          ? Center(
              child: IconButton.filledTonal(
                tooltip: 'More options',
                onPressed: () => setState(() => _showMore = true),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            )
          : AppCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Notes',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      filled: false,
                      hintText: 'Tap to add',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Label on the left, value or input on the right.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing, this.onTap});
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              if (trailing is Expanded)
                trailing
              else ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Expense / Income / Transfer / Goal pills; the selected one is filled
/// with the accent and shows a tick.
class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.selected, required this.onChanged});
  final EntryType selected;
  final ValueChanged<EntryType> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final (i, t) in const [
          EntryType.expense,
          EntryType.income,
          EntryType.transfer,
        ].indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: t == selected,
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: t == selected
                        ? scheme.primary
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          t == selected ? Icons.check_rounded : t.icon,
                          size: 16,
                          color: t == selected
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: t == selected
                                ? scheme.onPrimary
                                : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "₹ 1,250" centred as one unit, with an underline that grows with it.
class _AmountInput extends StatelessWidget {
  const _AmountInput({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle? style;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FormField<String>(
      validator: (_) => parsePaise(controller.text) == null
          ? 'Enter an amount, e.g. 250 or 99.50'
          : null,
      builder: (field) => Column(
        children: [
          ListenableBuilder(
            listenable: focusNode,
            builder: (context, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: focusNode.hasFocus ? 2 : 1,
                    color: field.hasError
                        ? scheme.error
                        : focusNode.hasFocus
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('₹', style: style?.copyWith(color: scheme.primary)),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      maxWidth: 260,
                    ),
                    child: IntrinsicWidth(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (v) {
                          field.didChange(v);
                          onChanged();
                        },
                        style: style,
                        decoration: InputDecoration(
                          filled: false,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          hintText: '0',
                          hintStyle: style?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                field.errorText!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// Category card: "Category  +" when empty, the chosen emoji and name
/// otherwise, with the subcategory dropdown underneath. Validates.
class _CategoryField extends FormField<CategoryOption> {
  _CategoryField({
    super.key,
    required CategoryOption? selected,
    required VoidCallback onTap,
    Widget? subcategory,
  }) : super(
         validator: (_) => selected == null ? 'Pick a category' : null,
         builder: (field) {
           final theme = Theme.of(field.context);
           final scheme = theme.colorScheme;
           return Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               Container(
                 decoration: BoxDecoration(
                   color: scheme.surfaceContainerHighest.withValues(
                     alpha: 0.35,
                   ),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(
                     color: field.hasError && selected == null
                         ? scheme.error
                         : scheme.outlineVariant.withValues(alpha: 0.3),
                   ),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                     InkWell(
                       borderRadius: BorderRadius.circular(12),
                       onTap: onTap,
                       child: Padding(
                         padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                         child: Row(
                           children: [
                             AnimatedSwitcher(
                               duration: const Duration(milliseconds: 200),
                               child: selected == null
                                   ? Icon(
                                       Icons.grid_view_rounded,
                                       color: scheme.onSurfaceVariant,
                                     )
                                   : Container(
                                       key: ValueKey(selected.name),
                                       width: 44,
                                       height: 44,
                                       alignment: Alignment.center,
                                       decoration: BoxDecoration(
                                         color: scheme.primary.withValues(
                                           alpha: 0.14,
                                         ),
                                         borderRadius: BorderRadius.circular(
                                           14,
                                         ),
                                       ),
                                       child: Text(
                                         selected.emoji,
                                         style: const TextStyle(fontSize: 22),
                                       ),
                                     ),
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   if (selected != null)
                                     Text(
                                       'Category',
                                       style: theme.textTheme.labelSmall
                                           ?.copyWith(
                                             color: scheme.onSurfaceVariant,
                                           ),
                                     ),
                                   Text(
                                     selected?.name ?? 'Category',
                                     style: theme.textTheme.titleMedium
                                         ?.copyWith(
                                           fontWeight: FontWeight.w700,
                                         ),
                                   ),
                                 ],
                               ),
                             ),
                             Icon(
                               selected == null
                                   ? Icons.add_rounded
                                   : Icons.edit_outlined,
                               color: selected == null
                                   ? scheme.onSurface
                                   : scheme.onSurfaceVariant,
                               size: selected == null ? 26 : 20,
                             ),
                           ],
                         ),
                       ),
                     ),
                     AnimatedSize(
                       duration: const Duration(milliseconds: 200),
                       alignment: Alignment.topCenter,
                       child: subcategory == null
                           ? const SizedBox(width: double.infinity)
                           : Padding(
                               padding: const EdgeInsets.fromLTRB(
                                 12,
                                 0,
                                 12,
                                 12,
                               ),
                               child: subcategory,
                             ),
                     ),
                   ],
                 ),
               ),
               if (field.hasError && selected == null)
                 Padding(
                   padding: const EdgeInsets.only(left: 16, top: 8),
                   child: Text(
                     field.errorText!,
                     style: theme.textTheme.bodySmall?.copyWith(
                       color: scheme.error,
                     ),
                   ),
                 ),
             ],
           );
         },
       );
}

/// "Every [–] N [+] [unit]" under the Repeat switch.
class _RepeatRow extends StatelessWidget {
  const _RepeatRow({
    required this.isExpense,
    required this.every,
    required this.unit,
    required this.onEvery,
    required this.onUnit,
  });
  final bool isExpense;
  final int every;
  final RepeatUnit unit;
  final ValueChanged<int> onEvery;
  final ValueChanged<RepeatUnit> onUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isExpense ? 'Recurring bill' : 'Recurring income'} · repeats every ${every == 1 ? unit.one.toLowerCase() : '$every ${unit.many.toLowerCase()}'}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Every', style: theme.textTheme.bodyLarge),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: every > 1 ? () => onEvery(every - 1) : null,
                icon: const Icon(Icons.remove),
                tooltip: 'Fewer',
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$every',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton.outlined(
                onPressed: every < 99 ? () => onEvery(every + 1) : null,
                icon: const Icon(Icons.add),
                tooltip: 'More',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<RepeatUnit>(
                  value: unit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    for (final u in RepeatUnit.values)
                      DropdownMenuItem(
                        value: u,
                        child: Text(every == 1 ? u.one : u.many),
                      ),
                  ],
                  onChanged: (u) => onUnit(u!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Grid of emoji tiles, four per row. Also a form field so it can show
/// "Pick a category" when nothing is chosen.
class _CategoryPicker extends FormField<CategoryOption> {
  _CategoryPicker({
    required List<CategoryOption> categories,
    required CategoryOption? selected,
    required Color color,
    required ValueChanged<CategoryOption> onChanged,
  }) : super(
         initialValue: selected,
         validator: (c) => c == null ? 'Pick a category' : null,
         builder: (field) {
           final theme = Theme.of(field.context);
           final scheme = theme.colorScheme;
           return Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               LayoutBuilder(
                 builder: (context, box) {
                   const gap = 8.0;
                   final tile = (box.maxWidth - gap * 3) / 4;
                   return Wrap(
                     spacing: gap,
                     runSpacing: gap,
                     children: [
                       for (final c in categories)
                         _CategoryTile(
                           category: c,
                           width: tile,
                           color: color,
                           selected: c == field.value,
                           onTap: () {
                             field.didChange(c);
                             onChanged(c);
                           },
                         ),
                     ],
                   );
                 },
               ),
               if (field.hasError)
                 Padding(
                   padding: const EdgeInsets.only(left: 12, top: 8),
                   child: Text(
                     field.errorText!,
                     style: theme.textTheme.bodySmall?.copyWith(
                       color: scheme.error,
                     ),
                   ),
                 ),
             ],
           );
         },
       );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.width,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final CategoryOption category;
  final double width;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1,
                duration: const Duration(milliseconds: 180),
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling row of choice chips, optionally with icons.
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.options,
    required this.selected,
    required this.color,
    required this.onSelected,
    this.icons = const {},
    this.endPadding = 0,
  });

  /// Space after the last chip; lets the row run to the card's edge.
  final double endPadding;
  final List<String> options;
  final String? selected;
  final Color color;
  final ValueChanged<String> onSelected;
  final Map<String, IconData> icons;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(right: endPadding),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final o = options[i];
          final isSelected = o == selected;
          return ChoiceChip(
            label: Text(o),
            avatar: icons[o] == null
                ? null
                : Icon(
                    icons[o],
                    size: 18,
                    color: isSelected ? color : scheme.onSurfaceVariant,
                  ),
            showCheckmark: false,
            selected: isSelected,
            onSelected: (_) => onSelected(o),
            selectedColor: color.withValues(alpha: 0.14),
            labelStyle: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? color : scheme.onSurface,
            ),
            side: BorderSide(color: isSelected ? color : scheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }
}

/// From → To account picker with a swap button between the two.
class _TransferCard extends FormField<void> {
  _TransferCard({
    required String? from,
    required String? to,
    required Color color,
    required ValueChanged<String> onFrom,
    required ValueChanged<String> onTo,
    required VoidCallback onSwap,
  }) : super(
         validator: (_) {
           if (from == null) return 'Pick where the money comes from';
           if (to == null) return 'Pick where the money goes';
           if (from == to) return 'From and To must be different';
           return null;
         },
         builder: (field) {
           final theme = Theme.of(field.context);
           final scheme = theme.colorScheme;
           return Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               Container(
                 // No right padding: chip rows scroll to the card's edge,
                 // with space only after the last chip.
                 padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                 clipBehavior: Clip.antiAlias,
                 decoration: BoxDecoration(
                   color: scheme.surfaceContainerHighest.withValues(
                     alpha: 0.35,
                   ),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(
                     color: field.hasError
                         ? scheme.error
                         : scheme.outlineVariant.withValues(alpha: 0.3),
                   ),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                     const _SectionLabel('From'),
                     _ChipRow(
                       options: accounts,
                       icons: accountIcons,
                       selected: from,
                       color: color,
                       onSelected: onFrom,
                       endPadding: 16,
                     ),
                     Padding(
                       padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
                       child: Row(
                         children: [
                           const Expanded(child: Divider()),
                           IconButton.filledTonal(
                             onPressed: onSwap,
                             tooltip: 'Swap',
                             icon: const Icon(Icons.swap_vert_rounded),
                           ),
                           const Expanded(child: Divider()),
                         ],
                       ),
                     ),
                     const _SectionLabel('To'),
                     _ChipRow(
                       options: accounts,
                       icons: accountIcons,
                       selected: to,
                       color: color,
                       onSelected: onTo,
                       endPadding: 16,
                     ),
                   ],
                 ),
               ),
               if (field.hasError)
                 Padding(
                   padding: const EdgeInsets.only(left: 12, top: 8),
                   child: Text(
                     field.errorText!,
                     style: theme.textTheme.bodySmall?.copyWith(
                       color: scheme.error,
                     ),
                   ),
                 ),
             ],
           );
         },
       );
}

/// Shows how far along the goal already is.
class _GoalProgress extends StatelessWidget {
  const _GoalProgress({
    required this.saved,
    required this.target,
    required this.color,
  });
  final int saved;
  final int target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = target == 0 ? 0.0 : saved / target;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${(share * 100).round()}% there',
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
              const Spacer(),
              Text(
                '${Money.format(target - saved)} to go',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
