import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/design/design.dart';
import '../../core/navigation/page_route.dart';
import '../../core/utils/money.dart';
import '../history/history_screen.dart';
import '../transactions/data/entry_repository.dart';
import '../transactions/data/transaction_options.dart';
import '../transactions/screens/add_transaction_screen.dart';
import 'account_balances.dart';

/// Where your money is: each account's balance and the total.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final balances = ref.watch(accountBalancesProvider);
    final total = balances.values.fold(0, (s, v) => s + v);
    const on = HeroCard.foreground;

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          FadeSlideIn(
            child: HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Across all accounts',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: on.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (total < 0)
                        Text(
                          '−',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: on,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      AnimatedMoney(
                        total.abs(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: on,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: on.withValues(alpha: 0.16),
                      foregroundColor: on,
                    ),
                    onPressed: () => showAddTransactionScreen(
                      context,
                      initialType: EntryType.transfer,
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Move money'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Your accounts'),
          for (final (i, a) in accounts.indexed) ...[
            FadeSlideIn(
              index: i + 1,
              child: _AccountTile(name: a, paise: balances[a] ?? 0),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Text(
            'Spending and income count against the account their payment '
            'method uses: UPI, debit card and net banking use your Bank '
            'account; Cash, Credit card and Wallet use their own. Tap an '
            'account to set its current balance.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
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
    final isCard = name == 'Credit card';
    // A credit card below zero is money owed, not a loss.
    final label = paise < 0
        ? (isCard ? '${Money.format(-paise)} owed' : '−${Money.format(-paise)}')
        : Money.format(paise);
    final color = paise < 0 && !isCard
        ? FinanceColors.expense
        : scheme.onSurface;

    return AppCard(
      onTap: () => _actions(context, ref),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          IconBadge.icon(accountIcons[name] ?? Icons.account_balance_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
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
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('See transactions'),
              onTap: () => Navigator.pop(c, 'see'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
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
