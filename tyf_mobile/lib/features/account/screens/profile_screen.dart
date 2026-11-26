import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/shell/app_drawer.dart' show syncLabel;
import '../../../core/design/design.dart';
import '../../../core/navigation/page_route.dart';
import '../../budgets/data/budget_repository.dart';
import '../../sync/sync_controller.dart';
import '../../transactions/data/entry_repository.dart';
import '../../transactions/data/transaction_options.dart';
import '../data/account.dart';
import '../../../app/shell/top_bar.dart' show hideBalanceProvider;
import '../../../core/utils/money.dart';
import '../../../core/widgets/option_row.dart';
import '../../accounts/account_balances.dart';
import '../../accounts/accounts_screen.dart';
import '../../reports/report_month_picker.dart';
import '../data/csv_export.dart';
import 'sign_in_screen.dart';
import 'sign_out_flow.dart';
import '../../../core/design/app_icons.dart';

/// Who you are in TYF: name, account and backup, a few numbers.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref
        .watch(accountBalancesProvider)
        .values
        .fold(0, (s, v) => s + v);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final account = ref.watch(accountProvider);
    final sync = ref.watch(syncProvider);
    final entries = ref.watch(entriesProvider).value ?? const [];
    final budgets = ref.watch(budgetsProvider).value ?? const [];
    final now = DateTime.now();
    final name = (account.name?.isNotEmpty ?? false) ? account.name! : 'You';
    final count = entries
        .where((e) => !e.isDeleted && e.type != EntryType.goal)
        .length;
    final since = account.trialStartedAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          FadeSlideIn(
            child: HeroCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: HeroCard.foreground.withValues(
                      alpha: 0.18,
                    ),
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: HeroCard.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: HeroCard.foreground,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          account.isGuest ? 'Guest' : account.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: HeroCard.foreground.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit name',
                    color: HeroCard.foreground,
                    onPressed: () => _editName(context, ref, account.name),
                    icon: const Icon(AppIcons.editOutlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            index: 1,
            child: Row(
              children: [
                _Stat(value: '$count', label: 'Transactions'),
                const SizedBox(width: 10),
                _Stat(value: '${budgets.length}', label: 'Budgets'),
                const SizedBox(width: 10),
                _Stat(
                  value: since == null
                      ? '—'
                      : DateFormat('MMM y').format(since),
                  label: 'Using TYF since',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const OptionSection(AppIcons.cloudSyncOutlined, 'Account & Backup'),
          FadeSlideIn(
            index: 2,
            child: AppCard(
              child: account.isGuest
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${account.daysLeft(now)} days left in your free trial',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your data is only on this phone. Sign in to back it '
                          'up and use it on any phone.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            appPageRoute<void>(
                              const SignInScreen(mode: SignInMode.voluntary),
                            ),
                          ),
                          icon: const Icon(AppIcons.cloudUploadOutlined),
                          label: const Text('Sign in to back up'),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        IconBadge.icon(
                          sync.error != null
                              ? AppIcons.cloudOffOutlined
                              : AppIcons.cloudDoneOutlined,
                          color: sync.error != null ? scheme.error : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backed up to your account',
                                style: theme.textTheme.titleSmall,
                              ),
                              Text(
                                syncLabel(sync),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: sync.error != null
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: sync.syncing
                              ? null
                              : () => ref.read(syncProvider.notifier).syncNow(),
                          child: Text(
                            sync.syncing ? 'Backing up…' : 'Back up now',
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          // ── Your money ──
          const OptionSection(
            AppIcons.accountBalanceWalletOutlined,
            'Your Money',
          ),
          OptionRow(
            icon: AppIcons.accountBalanceWalletOutlined,
            color: const Color(0xFF8B7CF6),
            title: 'Accounts',
            subtitle: ref.watch(hideBalanceProvider)
                ? 'Cash, bank, savings, card and wallet'
                : '${Money.format(total.abs())}${total < 0 ? ' overdrawn' : ''} across all accounts',
            onTap: () => Navigator.of(
              context,
            ).push(appPageRoute<void>(const AccountsScreen())),
          ),
          OptionRow(
            icon: AppIcons.visibilityOffOutlined,
            color: const Color(0xFF2EC4C4),
            title: 'Hide balance',
            subtitle: 'Show ₹ • • • • • instead of amounts',
            trailing: Switch(
              value: ref.watch(hideBalanceProvider),
              onChanged: (_) => ref.read(hideBalanceProvider.notifier).toggle(),
            ),
            onTap: () => ref.read(hideBalanceProvider.notifier).toggle(),
          ),
          // ── Your data ──
          const OptionSection(AppIcons.databaseOutlined, 'Your Data'),
          OptionRow(
            icon: AppIcons.downloadRounded,
            color: const Color(0xFF34C77B),
            title: 'Export to CSV',
            subtitle: 'Open in Excel or Google Sheets',
            onTap: () async {
              final all = ref.read(entriesProvider).value ?? const [];
              if (all.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('No transactions to export yet'),
                  ),
                );
                return;
              }
              await shareEntriesCsv(all);
            },
          ),
          OptionRow(
            icon: AppIcons.filePdf,
            color: const Color(0xFFF0616D),
            title: 'PDF report',
            subtitle: 'A monthly report to save, print or share',
            onTap: () => pickAndShareReport(context, ref),
          ),
          if (!account.isGuest) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
              ),
              onPressed: () => confirmSignOut(context, ref),
              icon: const Icon(AppIcons.logoutRounded),
              label: const Text('Sign out'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final c = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
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
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(accountProvider.notifier).rename(name);
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
