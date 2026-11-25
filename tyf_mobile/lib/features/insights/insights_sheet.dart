import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_theme.dart';
import '../../core/design/design.dart';
import '../../core/utils/money.dart';
import '../budgets/data/budget_repository.dart';
import '../budgets/widgets/budget_progress_bar.dart';
import '../categories/data/category_repository.dart';
import '../reports/data/month_report.dart';
import '../transactions/data/entry.dart';
import '../transactions/data/transaction_options.dart';
import '../transactions/data/entry_repository.dart';

/// One plain-language fact about this month.
class Insight {
  const Insight(this.emoji, this.title, this.detail, {this.tone});
  final String emoji;
  final String title;
  final String detail;

  /// Colour for good (green) or warning (red) news; null is neutral.
  final Color? tone;
}

/// Works out what's worth knowing right now, most useful first.
List<Insight> buildInsights({
  required List<Entry> entries,
  required List<BudgetProgress> budgets,
  required String? Function(String) emojiFor,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final r = MonthReport.build(
    entries,
    DateTime(today.year, today.month),
    now: today,
    emojiFor: emojiFor,
  );
  final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
  final daysLeft = daysInMonth - today.day + 1;
  final out = <Insight>[];

  // 1. Safe to spend per day, from budgets if set, else from income.
  final over = budgets.where((b) => b.isOver).toList();
  final overNames = over
      .map((b) => '${b.budget.category} by ${Money.format(-b.leftPaise)}')
      .join(', ');
  final limit = budgets.fold(0, (s, b) => s + b.budget.limitPaise);
  var overShown = false;
  final spentInBudgets = budgets.fold(0, (s, b) => s + b.spentPaise);
  if (limit > 0) {
    final left = limit - spentInBudgets;
    out.add(
      left > 0
          ? Insight(
              '🛡️',
              '${Money.format(left ~/ daysLeft)} a day',
              'You can spend this each day for the next $daysLeft days and stay within your budgets.',
              tone: FinanceColors.income,
            )
          : Insight(
              '🚨',
              'Budgets used up',
              "You've spent ${Money.format(-left)} more than your budgets allow this month"
                  '${over.isEmpty ? '.' : ': $overNames.'}',
              tone: FinanceColors.expense,
            ),
    );
    overShown = left <= 0;
  } else if (r.income > 0) {
    final left = r.income - r.expense;
    out.add(
      Insight(
        left > 0 ? '🛡️' : '🚨',
        left > 0
            ? '${Money.format(left ~/ daysLeft)} a day'
            : 'Spending more than you earn',
        left > 0
            ? 'Spend up to this each day for the next $daysLeft days and you still end the month with savings.'
            : 'This month you have spent ${Money.format(-left)} more than came in.',
        tone: left > 0 ? FinanceColors.income : FinanceColors.expense,
      ),
    );
  }

  // 2. Today against the usual day.
  final spentToday = entries
      .where(
        (e) =>
            !e.isDeleted &&
            e.type == EntryType.expense &&
            DateUtils.isSameDay(e.date, today),
      )
      .fold(0, (s, e) => s + e.amountPaise);
  final avg = r.perDay;
  if (spentToday == 0) {
    out.add(
      const Insight('✨', 'Nothing spent today', 'A no-spend day so far. Nice.'),
    );
  } else {
    final high = avg > 0 && spentToday > avg * 1.5;
    out.add(
      Insight(
        high ? '📈' : '☕',
        '${Money.format(spentToday)} spent today',
        avg > 0
            ? high
                  ? 'More than your usual ${Money.format(avg)} a day this month.'
                  : 'Within your usual ${Money.format(avg)} a day this month.'
            : 'Your first spending this month.',
        tone: high ? FinanceColors.expense : null,
      ),
    );
  }

  // 3. Budgets needing attention.
  final near = budgets.where((b) => b.isNear).toList();
  if (over.isNotEmpty && !overShown) {
    out.add(
      Insight(
        '⚠️',
        over.length == 1
            ? '${over.first.budget.category} is over budget'
            : '${over.length} budgets are over',
        overNames,
        tone: FinanceColors.expense,
      ),
    );
  }
  if (near.isNotEmpty) {
    final b = near.first;
    out.add(
      Insight(
        '⏳',
        '${b.budget.category} is almost used up',
        'Only ${Money.format(b.leftPaise)} left of ${Money.format(b.budget.limitPaise)}'
            '${near.length > 1 ? ', and ${near.length - 1} more close to the limit' : ''}.',
        tone: budgetWarning,
      ),
    );
  }

  // 4. Where most of the money goes.
  if (r.categories.isNotEmpty) {
    final top = r.categories.first;
    out.add(
      Insight(
        top.emoji ?? '💸',
        '${top.name} is your biggest spend',
        '${Money.format(top.paise)} so far, ${(top.share * 100).round()}% of everything you spent this month.',
      ),
    );
  }

  // 5. Compared with last month.
  final vs = r.vsLastMonth;
  if (vs != null && vs.abs() >= 0.05) {
    final pct = (vs.abs() * 100).round();
    out.add(
      Insight(
        vs > 0 ? '🔺' : '🔻',
        vs > 0 ? '$pct% more than last month' : '$pct% less than last month',
        'You have spent ${Money.format(r.expense)} in ${DateFormat.MMMM().format(today)}, against ${Money.format(r.previousExpense)} last month.',
        tone: vs > 0 ? FinanceColors.expense : FinanceColors.income,
      ),
    );
  }

  // 6. Savings.
  final rate = r.savingsRate;
  if (rate != null && rate > 0) {
    out.add(
      Insight(
        '💰',
        'Saving ${(rate * 100).round()}% of your income',
        '${Money.format(r.saved)} kept this month so far.',
        tone: FinanceColors.income,
      ),
    );
  }

  if (out.length <= 1 && r.isEmpty) {
    out.add(
      const Insight(
        '📝',
        'Add a few transactions',
        'Tips about your spending show up here once there is something to look at.',
      ),
    );
  }
  return out;
}

/// The top-bar shortcut: a quick read of this month in plain words.
Future<void> showInsightsSheet(
  BuildContext context, {
  required VoidCallback onOpenReports,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => InsightsSheet(onOpenReports: onOpenReports),
);

class InsightsSheet extends ConsumerWidget {
  const InsightsSheet({super.key, required this.onOpenReports});
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cats = ref.watch(categorySetProvider);
    final insights = buildInsights(
      entries: ref.watch(entriesProvider).value ?? const [],
      budgets: ref.watch(budgetProgressProvider),
      emojiFor: cats.emojiFor,
    );
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Your month at a glance',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: insights.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    FadeSlideIn(index: i, child: _InsightCard(insights[i])),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () {
                  Navigator.pop(context);
                  onOpenReports();
                },
                icon: const Icon(Icons.insights_rounded),
                label: const Text('See full reports'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard(this.insight);
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = insight.tone;
    return AppCard(
      tint: tone,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge.emoji(
            insight.emoji,
            color: tone ?? theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
