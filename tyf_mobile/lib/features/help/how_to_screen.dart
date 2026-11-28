import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/widgets/inner_app_bar.dart';

/// A short guide to the app, one card per idea.
class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});

  static const _steps = [
    (
      '➕',
      'Add what you spend or earn',
      'Tap the big + at the bottom. Pick Expense, Income or Transfer, type '
          'the amount, choose a category and save. Use "Save & add another" '
          'for several in a row.',
    ),
    (
      '📅',
      'See your days on the calendar',
      'The Calendar tab shows what went in and out each day. Tap a day to '
          'see, edit or delete its entries.',
    ),
    (
      '🧾',
      'Find any transaction',
      'The History tab lists everything, newest first. Search by name, '
          'category or amount, and filter by type. Swipe left to delete '
          '(with Undo), right to copy it to today.',
    ),
    (
      '🎯',
      'Set budgets',
      'On the Budgets tab, set a monthly limit for a category. The bar turns '
          'amber near the limit and red when you go over.',
    ),
    (
      '🗂️',
      'Make categories yours',
      'Open Manage categories (at the bottom of Budgets, or in the menu) to '
          'add, rename or re-emoji categories and their sub-categories. Past '
          'entries follow a rename.',
    ),
    (
      '🔁',
      'Repeat regular payments',
      'Turn on Repeat when adding rent, a subscription or your salary. TYF '
          'adds it again on each due date.',
    ),
    (
      '✨',
      'Get quick insights',
      'The sparkle button at the top right sums up your month: what you can '
          'spend per day, budgets to watch and your biggest spend.',
    ),
    (
      '📊',
      'Read your analytics',
      'The Analytics tab shows your savings, where your money went, income '
          'vs expense, budgets and payment methods for this month, the last 6 '
          'months or the year, plus your savings trend.',
    ),
    (
      '🏁',
      'Save for goals',
      'Open Goals from the menu to save towards a trip, a phone or an '
          'emergency fund, and track how close you are.',
    ),
    (
      '☁️',
      'Back up by signing in',
      'As a guest your data stays on this phone. Sign in with Google or email '
          'to back it up and use it on another phone.',
    ),
    (
      '🎨',
      'Pick your colour',
      'Settings lets you change the accent colour of the whole app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const InnerAppBar(title: Text('How to use TYF')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _steps.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final (emoji, title, body) = _steps[i];
          return FadeSlideIn(
            index: i,
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge.emoji(emoji),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. $title',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
