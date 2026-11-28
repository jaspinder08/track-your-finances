import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/app_icons.dart';

/// Holds the currently viewed month on the Calendar tab so both the TopBar
/// month dropdown and CalendarScreen stay in sync.
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month);
  }

  void shift(int deltaMonths) {
    state = DateTime(state.year, state.month + deltaMonths);
  }
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, DateTime>(
  SelectedMonthNotifier.new,
);

/// Opens a clean month/year picker bottom sheet.
Future<void> showMonthPickerSheet(
  BuildContext context, {
  required DateTime selected,
  required ValueChanged<DateTime> onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => _MonthPickerSheet(
      initial: selected,
      onSelected: (m) {
        HapticFeedback.selectionClick();
        onSelected(m);
        Navigator.of(ctx).pop();
      },
    ),
  );
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.initial,
    required this.onSelected,
  });

  final DateTime initial;
  final ValueChanged<DateTime> onSelected;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous year',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _year--);
                },
                icon: const Icon(AppIcons.chevronLeftRounded),
              ),
              Expanded(
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next year',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _year++);
                },
                icon: const Icon(AppIcons.chevronRightRounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.3,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final monthNum = index + 1;
              final isSelected =
                  _year == widget.initial.year &&
                  monthNum == widget.initial.month;
              final isCurrent = _year == now.year && monthNum == now.month;
              final label = DateFormat('MMM').format(DateTime(_year, monthNum));

              return Material(
                color: isSelected
                    ? scheme.primary
                    : scheme.surfaceContainerHigh.withValues(alpha: 0.65),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? scheme.primary
                        : isCurrent
                        ? scheme.primary.withValues(alpha: 0.5)
                        : scheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onSelected(DateTime(_year, monthNum)),
                  child: Center(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? scheme.onPrimary
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

