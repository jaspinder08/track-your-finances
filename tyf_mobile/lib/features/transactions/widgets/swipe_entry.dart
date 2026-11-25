import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../data/entry.dart';
import '../data/entry_repository.dart';

/// Wraps an entry row with swipe actions:
/// swipe left → delete (with Undo), swipe right → duplicate to today.
class SwipeEntry extends ConsumerWidget {
  const SwipeEntry({super.key, required this.entry, required this.child});
  final Entry entry;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    Widget bg(Alignment at, Color color, IconData icon, String label) =>
        Container(
          color: color.withValues(alpha: 0.18),
          alignment: at,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );

    return Dismissible(
      key: ValueKey('swipe-${entry.id}'),
      background: bg(
        Alignment.centerLeft,
        scheme.primary,
        Icons.copy_rounded,
        'Duplicate',
      ),
      secondaryBackground: bg(
        Alignment.centerRight,
        FinanceColors.expense,
        Icons.delete_outline_rounded,
        'Delete',
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          // Duplicate keeps the row in place.
          HapticFeedback.lightImpact();
          await duplicateEntry(context, ref, entry);
          return false;
        }
        return true;
      },
      onDismissed: (_) => deleteEntry(context, ref, entry),
      child: child,
    );
  }
}

/// Deletes [entry] and offers Undo for a few seconds.
Future<void> deleteEntry(
  BuildContext context,
  WidgetRef ref,
  Entry entry,
) async {
  HapticFeedback.mediumImpact();
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(entriesProvider.notifier);
  await notifier.delete(entry.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Text(
          'Deleted ${entry.title} · ${Money.format(entry.amountPaise)}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.restore(entry.id),
        ),
      ),
    );
}

/// Adds a copy of [entry] dated today.
Future<void> duplicateEntry(
  BuildContext context,
  WidgetRef ref,
  Entry entry,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(entriesProvider.notifier).duplicate(entry);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Added ${entry.title} · ${Money.format(entry.amountPaise)} for today',
        ),
      ),
    );
}
