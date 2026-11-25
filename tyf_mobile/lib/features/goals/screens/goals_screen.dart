import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/data/transaction_options.dart';
import '../../transactions/screens/add_transaction_sheet.dart';
import '../data/goal.dart';
import 'goals_view.dart';

/// Goals page, opened from the sidebar. "New goal" is a floating button
/// (bottom-right, thumb reach) that shrinks to "+" while scrolling down.
/// It's hidden when there are no goals: the empty state has its own
/// "Create a goal" button.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  bool _extended = true;

  bool _onScroll(UserScrollNotification n) {
    final e = switch (n.direction) {
      ScrollDirection.reverse => false, // scrolling down the list
      ScrollDirection.forward => true,
      ScrollDirection.idle => _extended,
    };
    if (e != _extended) setState(() => _extended = e);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasGoals = ref.watch(goalsProvider).isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: hasGoals
          ? FloatingActionButton.extended(
              tooltip: 'New goal',
              isExtended: _extended,
              onPressed: () =>
                  showAddTransactionSheet(context, initialType: EntryType.goal),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New goal'),
            )
          : null,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: const GoalsView(),
      ),
    );
  }
}
