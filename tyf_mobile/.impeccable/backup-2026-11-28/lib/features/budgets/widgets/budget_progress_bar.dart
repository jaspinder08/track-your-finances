import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/design/motion.dart';

/// Amber for "almost there".
const budgetWarning = Color(0xFFF5A524);

/// Accent while on track, amber from 80%, red when over.
Color budgetColor(BuildContext context, double ratio) => ratio > 1
    ? FinanceColors.expense
    : ratio >= 0.8
    ? budgetWarning
    : Theme.of(context).colorScheme.primary;

/// Rounded progress bar that animates to [ratio] (capped at 100%).
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.ratio,
    required this.color,
    this.height = 10,
  });
  final double ratio;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(TabVisit.of(context)),
      tween: Tween(begin: 0, end: ratio.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: color,
          backgroundColor: color.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}
