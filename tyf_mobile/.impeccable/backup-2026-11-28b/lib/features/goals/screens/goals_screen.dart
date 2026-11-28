import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/data/transaction_options.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import 'goals_view.dart';
import '../../../core/design/app_icons.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      // Always there, so adding a goal is one tap from anywhere.
      floatingActionButton: FloatingActionButton(
        tooltip: 'New goal',
        onPressed: () =>
            showAddTransactionScreen(context, initialType: EntryType.goal),
        shape: const CircleBorder(),
        child: const Icon(AppIcons.addRounded, size: 28),
      ),
      body: const GoalsView(),
    );
  }
}
