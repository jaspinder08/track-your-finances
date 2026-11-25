import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../theme/app_theme.dart';
import '../../core/widgets/round_icon_button.dart';

/// Top bar shared by the main tabs: menu, balance pill, reports shortcut.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.balancePaise,
    required this.onMenu,
    required this.onReports,
    this.onBalance,
    this.compact = false,
  });

  final int balancePaise;
  final VoidCallback onMenu;
  final VoidCallback onReports;

  /// Tapping the balance pill (opens Accounts).
  final VoidCallback? onBalance;

  /// Slimmer bar once the page is scrolled, to give lists more room.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(16, compact ? 2 : 8, 16, compact ? 2 : 8),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.menu_rounded,
            onPressed: onMenu,
            tooltip: 'Menu',
          ),
          const Spacer(),
          GestureDetector(
            onTap: onBalance,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                horizontal: 22,
                vertical: compact ? 4 : 8,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: compact
                        ? const SizedBox(width: 0, height: 0)
                        : Text(
                            'BALANCE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  SizedBox(height: compact ? 0 : 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(a),
                        child: c,
                      ),
                    ),
                    child: Text(
                      '${balancePaise < 0 ? '−' : ''}${Money.format(balancePaise.abs())}',
                      key: ValueKey(balancePaise),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: balancePaise < 0
                            ? FinanceColors.expense
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          RoundIconButton(
            icon: Icons.auto_awesome_rounded,
            onPressed: onReports,
            tooltip: 'Insights',
          ),
        ],
      ),
    );
  }
}
