import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';
import '../data/category_repository.dart';

/// Emoji the picker offers, grouped loosely by theme.
const _emojiChoices = [
  '🏠',
  '🍔',
  '🛒',
  '🍕',
  '☕',
  '🍺',
  '🚗',
  '⛽',
  '🚌',
  '✈️',
  '🏨',
  '🎬',
  '🎮',
  '🎵',
  '🛍️',
  '👕',
  '👟',
  '💄',
  '💆',
  '💇',
  '🏋️',
  '💊',
  '🩺',
  '🦷',
  '📚',
  '🎓',
  '💻',
  '📱',
  '🧾',
  '💡',
  '💧',
  '🔥',
  '📶',
  '💳',
  '🏦',
  '📈',
  '💰',
  '💼',
  '🧑‍💻',
  '🏪',
  '🎁',
  '↩️',
  '🐶',
  '👶',
  '🧹',
  '🔧',
  '🌱',
  '🙏',
  '🎉',
  '⚽',
  '🏖️',
  '🚕',
  '🚆',
  '🏥',
  '🧴',
  '🪙',
  '🏷️',
  '✨',
];

/// Opens the editor for a new category, or for [existing] if given.
Future<void> showCategoryEditor(
  BuildContext context, {
  required CategoryKind kind,
  CategoryOption? existing,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final msg = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => CategoryEditorSheet(kind: kind, existing: existing),
  );
  if (msg != null) {
    messenger.showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
  }
}

class CategoryEditorSheet extends ConsumerStatefulWidget {
  const CategoryEditorSheet({super.key, required this.kind, this.existing});
  final CategoryKind kind;
  final CategoryOption? existing;

  @override
  ConsumerState<CategoryEditorSheet> createState() => _State();
}

class _State extends ConsumerState<CategoryEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  final _sub = TextEditingController();
  late String _emoji = widget.existing?.emoji ?? '🏷️';
  late final List<String> _subs = [...?widget.existing?.subcategories];
  String? _subError;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _sub.dispose();
    super.dispose();
  }

  void _addSub() {
    final s = _sub.text.trim();
    if (s.isEmpty) return;
    if (_subs.any((x) => x.toLowerCase() == s.toLowerCase())) {
      setState(() => _subError = '"$s" is already in the list');
      return;
    }
    setState(() {
      _subs.add(s);
      _subError = null;
      _sub.clear();
    });
  }

  Future<void> _save() async {
    _addSub(); // keep anything typed but not yet added
    if (!_formKey.currentState!.validate()) return;
    final c = CategoryOption(_name.text.trim(), _emoji, List.of(_subs));
    final n = ref.read(categoriesProvider.notifier);
    if (_editing) {
      await n.replace(widget.kind, widget.existing!.name, c);
    } else {
      await n.add(widget.kind, c);
    }
    if (mounted) {
      Navigator.pop(
        context,
        '${c.emoji} ${c.name} ${_editing ? 'updated' : 'added'}',
      );
    }
  }

  Future<void> _delete() async {
    final name = widget.existing!.name;
    final used = (ref.read(entriesProvider).value ?? const [])
        .where(
          (e) => e.type == widget.kind.entryType && e.data.category == name,
        )
        .length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?'),
        content: Text(
          used == 0
              ? 'It isn\'t used by any entries.'
              : '$used ${used == 1 ? 'entry keeps' : 'entries keep'} the name "$name", but you won\'t be able to pick it for new ones.',
        ),
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
    await ref.read(categoriesProvider.notifier).remove(widget.kind, name);
    if (mounted) Navigator.pop(context, '$name deleted');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: Container(
                      key: ValueKey(_emoji),
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editing ? 'Edit category' : 'New category',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          '${widget.kind.label} category',
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
                    ),
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
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
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 24,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.label_outline),
                        counterText: '',
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'Give it a name';
                        final taken = ref
                            .read(categoriesProvider.notifier)
                            .nameTaken(
                              widget.kind,
                              s,
                              except: widget.existing?.name,
                            );
                        return taken ? 'You already have "$s"' : null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _label(context, 'Icon'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in _emojiChoices)
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _emoji = e),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: e == _emoji
                                    ? scheme.primary.withValues(alpha: 0.14)
                                    : scheme.surfaceContainerHighest.withValues(
                                        alpha: 0.45,
                                      ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: e == _emoji
                                      ? scheme.primary
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _label(context, 'Subcategories (optional)'),
                    if (_subs.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in _subs)
                            InputChip(
                              label: Text(s),
                              onDeleted: () => setState(() => _subs.remove(s)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _sub,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _addSub(),
                      decoration: InputDecoration(
                        labelText: 'Add a subcategory',
                        prefixIcon: const Icon(
                          Icons.subdirectory_arrow_right_rounded,
                        ),
                        errorText: _subError,
                        suffixIcon: IconButton(
                          tooltip: 'Add subcategory',
                          icon: const Icon(Icons.add_circle_rounded),
                          color: scheme.primary,
                          onPressed: _addSub,
                        ),
                      ),
                    ),
                    if (_editing) ...[
                      const SizedBox(height: 20),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete category'),
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
