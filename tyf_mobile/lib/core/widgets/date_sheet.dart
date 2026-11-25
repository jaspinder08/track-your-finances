import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/tokens.dart';

/// Picks a day: quick picks for the last week, then a month calendar.
/// Returns null if dismissed.
Future<DateTime?> showDateSheet(
  BuildContext context, {
  required DateTime initial,
  DateTime? first,
  DateTime? last,
}) => showModalBottomSheet<DateTime>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => DateSheet(
    initial: initial,
    first: first ?? DateTime(2000),
    last: last ?? DateTime(2100),
  ),
);

class DateSheet extends StatefulWidget {
  const DateSheet({
    super.key,
    required this.initial,
    required this.first,
    required this.last,
  });
  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<DateSheet> {
  late DateTime _day = DateUtils.dateOnly(widget.initial);
  // Bumped to make the calendar jump to the picked month.
  int _jump = 0;

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  String _relative(DateTime d) {
    final diff = _today.difference(d).inDays;
    return switch (diff) {
      0 => 'Today',
      1 => 'Yesterday',
      -1 => 'Tomorrow',
      > 1 && < 7 => '$diff days ago',
      _ => DateFormat.EEEE().format(d),
    };
  }

  void _quick(DateTime d) => setState(() {
    _day = d;
    _jump++;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quick = [
      for (var i = 0; i < 7; i++) _today.subtract(Duration(days: i)),
    ];

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The chosen day, big.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: Column(
                key: ValueKey(_day),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _relative(_day),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('EEE, d MMMM y').format(_day),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Last 7 days, one tap.
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: quick.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = quick[i];
                final sel = DateUtils.isSameDay(d, _day);
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => _quick(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i < 2 ? 92 : 56,
                    decoration: BoxDecoration(
                      color: sel
                          ? scheme.primary
                          : scheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i == 0
                              ? 'Today'
                              : i == 1
                              ? 'Yesterday'
                              : DateFormat.E().format(d),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: sel
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${d.day}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: sel ? scheme.onPrimary : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Theme(
              data: theme.copyWith(
                datePickerTheme: DatePickerThemeData(
                  dayShape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  todayBorder: BorderSide(color: scheme.primary),
                  dayStyle: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              child: CalendarDatePicker(
                key: ValueKey(_jump),
                initialDate: _day,
                firstDate: widget.first,
                lastDate: widget.last,
                currentDate: _today,
                onDateChanged: (d) => setState(() => _day = d),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              onPressed: () => Navigator.pop(context, _day),
              child: Text(
                'Use ${_relative(_day).toLowerCase() == 'today' ? 'today' : DateFormat('d MMM').format(_day)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
