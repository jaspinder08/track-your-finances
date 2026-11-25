import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/data/entry.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';

/// A savings goal: a goal entry read as target, saved and deadline.
@immutable
class Goal {
  const Goal(this.entry, {DateTime? now}) : _now = now;
  final Entry entry;
  final DateTime? _now;

  String get id => entry.id;
  String get name => entry.data.name ?? 'Goal';
  int get targetPaise => entry.amountPaise;
  int get savedPaise => entry.data.savedSoFarPaise ?? 0;
  DateTime get targetDate => entry.date;

  int get leftPaise => (targetPaise - savedPaise).clamp(0, targetPaise);
  double get ratio => targetPaise == 0 ? 0 : savedPaise / targetPaise;
  bool get isDone => savedPaise >= targetPaise;

  DateTime get _today {
    final n = _now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get isOverdue => !isDone && targetDate.isBefore(_today);

  /// Calendar months until the target date, counting this one (min 1).
  int get monthsLeft {
    final m =
        (targetDate.year - _today.year) * 12 +
        targetDate.month -
        _today.month +
        1;
    return m < 1 ? 1 : m;
  }

  /// How much to put aside each month to finish on time.
  int get perMonthPaise => isDone ? 0 : (leftPaise / monthsLeft).ceil();
}

/// All goals, unfinished first (soonest deadline), then finished ones.
final goalsProvider = Provider<List<Goal>>((ref) {
  final goals = [
    for (final e in ref.watch(entriesProvider).value ?? const <Entry>[])
      if (e.type == EntryType.goal) Goal(e),
  ];
  goals.sort((a, b) {
    if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
    return a.targetDate.compareTo(b.targetDate);
  });
  return goals;
});
