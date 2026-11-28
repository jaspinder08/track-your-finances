import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_theme.dart';
import '../insights/insights_sheet.dart';
import '../../app/shell/top_bar.dart' show hideBalanceProvider;

import '../../core/design/design.dart';
import '../../core/navigation/page_route.dart';
import '../../core/utils/money.dart';
import '../history/history_screen.dart';
import '../transactions/data/entry_repository.dart';
import '../transactions/data/transaction_options.dart';
import '../transactions/screens/add_transaction_screen.dart';
import 'account_balances.dart';
import '../../core/design/app_icons.dart';

/// Each account's look: tile colour and a short description.
const _accountStyle = <String, (Color, String)>{
  'Cash': (Color(0xFF3B82F6), 'Physical cash'),
  'Bank account': (Color(0xFF8B7CF6), 'UPI, debit card & net banking'),
  'Savings account': (Color(0xFF34C77B), 'Money set aside'),
  'Credit card': (Color(0xFFEF8A3C), 'Card spending to pay back'),
  'Wallet': (Color(0xFFA06BF0), 'Paytm, PhonePe & other wallets'),
};

/// Where your money is: each account's balance and the total.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final balances = ref.watch(accountBalancesProvider);
    final total = balances.values.fold(0, (s, v) => s + v);
    // Total at the end of last month, for the comparison line.
    final now = DateTime.now();
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    final before = accountBalances(
      ref.watch(entriesProvider).value ?? const [],
      lastMonthEnd,
    ).values.fold(0, (s, v) => s + v);
    final change = total - before;
    final hidden = ref.watch(hideBalanceProvider);
    final on = scheme.onSurface;
    final dim = scheme.onSurfaceVariant;

    Widget round(IconData icon, String tip, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: IconButton.filledTonal(
        tooltip: tip,
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          fixedSize: const Size(48, 48),
          backgroundColor: scheme.cardFill(0.8),
        ),
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72,
        toolbarHeight: 68,
        leading: round(
          AppIcons.arrowBackRounded,
          'Back',
          () => Navigator.maybePop(context),
        ),
        title: const Text('Accounts'),
        actions: [
          round(
            AppIcons.addRounded,
            'Add a transaction',
            () => showAddTransactionScreen(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          FadeSlideIn(
            child: HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Across all accounts',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkResponse(
                                  radius: 18,
                                  onTap: () => ref
                                      .read(hideBalanceProvider.notifier)
                                      .toggle(),
                                  child: Icon(
                                    hidden
                                        ? AppIcons.visibilityOffOutlined
                                        : AppIcons.visibilityOutlined,
                                    size: 20,
                                    color: scheme.primary,
                                    semanticLabel: hidden
                                        ? 'Show balance'
                                        : 'Hide balance',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (hidden)
                              Text(
                                '₹ • • • • •',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: on,
                                ),
                              )
                            else
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    if (total < 0)
                                      Text(
                                        '−',
                                        style: theme.textTheme.displaySmall
                                            ?.copyWith(color: on),
                                      ),
                                    AnimatedMoney(
                                      total.abs(),
                                      style: theme.textTheme.displaySmall
                                          ?.copyWith(color: on),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  change >= 0
                                      ? AppIcons.arrowUpwardRounded
                                      : AppIcons.arrowDownwardRounded,
                                  size: 16,
                                  color: change >= 0
                                      ? FinanceColors.income
                                      : FinanceColors.expense,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    hidden
                                        ? 'Compared to last month'
                                        : '${Money.format(change.abs())} '
                                              '${change >= 0 ? 'more' : 'less'} '
                                              'than last month',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: dim,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const _WalletArt(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: scheme.primary,
                      backgroundColor: scheme.primary.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    onPressed: () => showAddTransactionScreen(
                      context,
                      initialType: EntryType.transfer,
                    ),
                    icon: Icon(
                      AppIcons.swapHorizRounded,
                      color: Color.lerp(scheme.primary, on, 0.3),
                    ),
                    label: const Text('Move money'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your Accounts',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => showInsightsSheet(
                  context,
                  onOpenReports: () => Navigator.maybePop(context),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.barChartRounded, size: 18),
                    const SizedBox(width: 6),
                    const Text('View Insights'),
                    const SizedBox(width: 2),
                    Icon(AppIcons.chevronRightRounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, a) in accounts.indexed) ...[
            FadeSlideIn(
              index: i + 1,
              child: _AccountTile(name: a, paise: balances[a] ?? 0),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          // Quick tip.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: scheme.cardFill(0.55),
              border: Border.all(color: scheme.cardBorder),
              boxShadow: scheme.cardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.infoOutlineRounded, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Tip',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Color.lerp(scheme.primary, Colors.white, 0.3),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap an account to set its balance to what your bank '
                        'or wallet shows. Spending counts against the account '
                        'its payment method uses: UPI, debit card and net '
                        'banking use your Bank account.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

/// A glowing wallet, drawn with icons, for the total card.
class _WalletArt extends StatelessWidget {
  const _WalletArt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Color.lerp(scheme.primary, const Color(0xFF8B5CF6), 0.5)!;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(c, Colors.white, 0.25)!,
                  Color.lerp(c, Colors.black, 0.2)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.55),
                  blurRadius: 26,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              AppIcons.accountBalanceWalletOutlined,
              color: Colors.white,
              size: 38,
            ),
          ),
          Positioned(
            top: 2,
            left: 4,
            child: Icon(
              AppIcons.autoAwesomeRounded,
              size: 18,
              color: Color.lerp(c, Colors.white, 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.name, required this.paise});
  final String name;
  final int paise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (color, about) = _accountStyle[name] ?? (scheme.primary, 'Account');
    final isCard = name == 'Credit card';
    final hidden = ref.watch(hideBalanceProvider);
    final label = hidden
        ? '₹ •••'
        : paise < 0
        ? (isCard ? '${Money.format(-paise)} owed' : '−${Money.format(-paise)}')
        : Money.format(paise);
    final valueColor = paise < 0 && !isCard && !hidden
        ? const Color(0xFFFF6B78)
        : scheme.onSurface;

    return Material(
      color: scheme.cardFill(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _actions(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.5),
                      color.withValues(alpha: 0.2),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 14,
                      spreadRadius: -4,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  accountIcons[name] ?? AppIcons.accountBalanceOutlined,
                  color: Color.lerp(color, Colors.white, 0.35),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      about,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(color: valueColor),
              ),
              const SizedBox(width: 6),
              Icon(
                AppIcons.chevronRightRounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.receiptLongOutlined),
              title: const Text('See transactions'),
              onTap: () => Navigator.pop(c, 'see'),
            ),
            ListTile(
              leading: const Icon(AppIcons.editOutlined),
              title: const Text('Set current balance'),
              subtitle: const Text('Match what your bank or wallet shows'),
              onTap: () => Navigator.pop(c, 'set'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'see') {
      await Navigator.of(
        context,
      ).push(appPageRoute<void>(HistoryScreen(account: name)));
    } else if (choice == 'set') {
      await _setBalance(context, ref);
    }
  }

  Future<void> _setBalance(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('$name balance'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: '0',
            helperText: name == 'Credit card'
                ? 'Use a minus for what you owe, e.g. -4500'
                : 'What it shows today',
          ),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final rupees = double.tryParse(value ?? '');
    if (rupees == null) return;
    final draft = adjustmentFor(
      name,
      paise,
      (rupees * 100).round(),
      DateTime.now(),
    );
    if (draft != null) await ref.read(entriesProvider.notifier).add(draft);
  }
}
