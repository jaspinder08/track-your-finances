import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../../core/widgets/round_icon_button.dart';
import '../../core/design/surface.dart';
import '../../core/design/app_icons.dart';

/// Top bar shared by the main tabs: menu, balance pill, reports shortcut.
/// Whether the balance is hidden (for using the app in public).
/// Remembered between launches.
final hideBalanceProvider = NotifierProvider<HideBalance, bool>(
  HideBalance.new,
);

class HideBalance extends Notifier<bool> {
  static const _k = 'hide_balance';

  @override
  bool build() => ref.read(sharedPreferencesProvider)?.getBool(_k) ?? false;

  void toggle() {
    state = !state;
    ref.read(sharedPreferencesProvider)?.setBool(_k, state);
  }
}

class TopBar extends ConsumerWidget {
  const TopBar({
    super.key,
    required this.balancePaise,
    required this.onMenu,
    required this.onReports,
    this.onBalance,
    this.compact = false,
    this.onScanSms,
  });

  final int balancePaise;
  final VoidCallback onMenu;
  final VoidCallback onReports;

  /// Tapping the balance pill (opens Accounts).
  final VoidCallback? onBalance;

  /// Slimmer bar once the page is scrolled, to give lists more room.
  final bool compact;

  /// Shown on the Calendar tab: opens Scan SMS.
  final VoidCallback? onScanSms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hideBalanceProvider);
    final theme = Theme.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(16, compact ? 2 : 8, 16, compact ? 2 : 8),
      child: Row(
        children: [
          RoundIconButton(
            icon: AppIcons.menuRounded,
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
                color: theme.colorScheme.isLight
                    ? Colors.white
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                borderRadius: BorderRadius.circular(28),
                border: theme.colorScheme.isLight
                    ? Border.all(color: theme.colorScheme.cardBorder)
                    : null,
                boxShadow: theme.colorScheme.cardShadow,
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
                    child: Row(
                      key: ValueKey('$hidden$balancePaise'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hidden
                              ? '₹ • • • • •'
                              : '${balancePaise < 0 ? '−' : ''}${Money.format(balancePaise.abs())}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: balancePaise < 0
                                ? FinanceColors.expense
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkResponse(
                          radius: 18,
                          onTap: () =>
                              ref.read(hideBalanceProvider.notifier).toggle(),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.16,
                              ),
                            ),
                            child: Icon(
                              hidden
                                  ? AppIcons.visibilityOffOutlined
                                  : AppIcons.visibilityOutlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                              semanticLabel: hidden
                                  ? 'Show balance'
                                  : 'Hide balance',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (onScanSms != null) ...[
            RoundIconButton(
              icon: AppIcons.chatText,
              onPressed: onScanSms!,
              tooltip: 'Scan SMS',
            ),
            const SizedBox(width: 8),
          ],
          RoundIconButton(
            icon: AppIcons.autoAwesomeRounded,
            onPressed: onReports,
            tooltip: 'Insights',
          ),
        ],
      ),
    );
  }
}
