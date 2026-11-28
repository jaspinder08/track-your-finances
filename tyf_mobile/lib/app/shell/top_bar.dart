import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../../core/widgets/round_icon_button.dart';
import '../../core/design/app_icons.dart';

/// Top bar shared by the main tabs: menu, centered month dropdown (on
/// Calendar) or balance pill (on other tabs), and right action(s).
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
    this.selectedMonth,
    this.onMonthTap,
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

  /// When non-null (Calendar tab), shows the month dropdown dead-center
  /// instead of the balance pill.
  final DateTime? selectedMonth;
  final VoidCallback? onMonthTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hideBalanceProvider);
    final theme = Theme.of(context);
    final isCalendar = selectedMonth != null;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(16, compact ? 2 : 8, 16, compact ? 2 : 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              RoundIconButton(
                icon: AppIcons.menuRounded,
                onPressed: onMenu,
                tooltip: 'Menu',
              ),
              const Spacer(),
              if (onScanSms != null)
                RoundIconButton(
                  icon: AppIcons.chatText,
                  onPressed: onScanSms!,
                  tooltip: 'Scan SMS',
                ),
              if (!isCalendar) ...[
                if (onScanSms != null) const SizedBox(width: 4),
                RoundIconButton(
                  icon: AppIcons.autoAwesomeRounded,
                  onPressed: onReports,
                  tooltip: 'Insights',
                ),
              ],
            ],
          ),
          if (isCalendar)
            Semantics(
              container: true,
              button: true,
              label:
                  'Select month, ${DateFormat('MMMM y').format(selectedMonth!)}',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onMonthTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMMM').format(selectedMonth!),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('y').format(selectedMonth!),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        AppIcons.expandMoreRounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Semantics(
              container: true,
              button: onBalance != null,
              label: hidden
                  ? 'Balance hidden'
                  : 'Balance ${balancePaise < 0 ? 'minus ' : ''}${Money.format(balancePaise.abs())}',
              hint: onBalance != null ? 'Open accounts' : null,
              onTap: onBalance,
              child: GestureDetector(
                onTap: onBalance,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: compact ? 2 : 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: compact
                            ? const SizedBox(width: 0, height: 0)
                            : ExcludeSemantics(
                                child: Text(
                                  'BALANCE',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
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
                            ExcludeSemantics(
                              child: Text(
                                hidden
                                    ? '₹ • • • • •'
                                    : '${balancePaise < 0 ? '−' : ''}${Money.format(balancePaise.abs())}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: balancePaise < 0
                                      ? FinanceColors.expenseOf(context)
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Semantics(
                              container: true,
                              button: true,
                              label: hidden ? 'Show balance' : 'Hide balance',
                              excludeSemantics: true,
                              child: InkResponse(
                                radius: 18,
                                onTap: () => ref
                                    .read(hideBalanceProvider.notifier)
                                    .toggle(),
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Icon(
                                    hidden
                                        ? AppIcons.visibilityOffOutlined
                                        : AppIcons.visibilityOutlined,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    semanticLabel: hidden
                                        ? 'Show balance'
                                        : 'Hide balance',
                                  ),
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
            ),
        ],
      ),
    );
  }
}
