import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sync/sync_controller.dart';

import '../../core/design/design.dart';
import '../theme/app_theme.dart';
import '../../core/navigation/page_route.dart';
import '../../features/account/data/account.dart';
import '../../features/account/screens/sign_out_flow.dart';
import '../../features/account/screens/profile_screen.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/help/how_to_screen.dart';
import '../../features/categories/screens/categories_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../core/design/app_icons.dart';

/// Side menu: greeting, account card, and the secondary pages.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  static const _version = 'v1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final account = ref.watch(accountProvider);
    final sync = ref.watch(syncProvider);
    final name = (account.name?.trim().isNotEmpty ?? false)
        ? account.name!.trim()
        : null;
    final initials = name == null
        ? ''
        : name
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .take(2)
              .map((w) => w.characters.first.toUpperCase())
              .join();

    void open(Widget page) {
      Navigator.of(context)
        ..pop()
        ..push(appPageRoute<void>(page));
    }

    Widget item(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? tint,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: (tint ?? scheme.primary).withValues(alpha: 0.14),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(icon, color: tint ?? scheme.onSurface, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tint,
                    ),
                  ),
                ),
                Icon(
                  AppIcons.chevronRightRounded,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Drawer(
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // Greeting → Profile.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 16, 20),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            scheme.primary,
                            const Color(0xFF8B5CF6),
                            scheme.primary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(
                            scheme.surfaceContainerHigh,
                            scheme.primary,
                            0.2,
                          ),
                        ),
                        child: name == null
                            ? Icon(
                                AppIcons.personOutlineRounded,
                                color: scheme.onSurface,
                                size: 28,
                              )
                            : Text(initials, style: theme.textTheme.titleLarge),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: name == null
                                      ? 'Hello there'
                                      : 'Hello, ',
                                ),
                                if (name != null)
                                  TextSpan(
                                    text: name,
                                    style: TextStyle(
                                      color: Color.lerp(
                                        scheme.primary,
                                        const Color(0xFFA78BFA),
                                        0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall,
                          ),
                          Text(
                            'Good to see you again!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Account status.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => open(const ProfileScreen()),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color:
                                  (account.isGuest
                                          ? const Color(0xFFF5A524)
                                          : FinanceColors.income)
                                      .withValues(alpha: 0.14),
                            ),
                            child: Icon(
                              account.isGuest
                                  ? AppIcons.crownSimple
                                  : AppIcons.verifiedUserOutlined,
                              color: account.isGuest
                                  ? const Color(0xFFF5A524)
                                  : FinanceColors.income,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.isGuest ? 'Guest' : 'Signed in',
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  account.isGuest
                                      ? '${account.daysLeft(DateTime.now())} days left in free trial'
                                      : account.email!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                if (!account.isGuest)
                                  Text(
                                    syncLabel(sync),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: sync.error != null
                                          ? scheme.error
                                          : scheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!account.isGuest)
                            IconButton(
                              tooltip: 'Back up now',
                              onPressed: sync.syncing
                                  ? null
                                  : () => ref
                                        .read(syncProvider.notifier)
                                        .syncNow(),
                              icon: sync.syncing
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(AppIcons.cloudSyncOutlined),
                            )
                          else
                            Icon(
                              AppIcons.chevronRightRounded,
                              color: scheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              item(
                AppIcons.accountBalanceWalletOutlined,
                'Accounts',
                () => open(const AccountsScreen()),
              ),
              item(
                AppIcons.gridViewRounded,
                'Categories',
                () => open(const CategoriesScreen()),
              ),
              item(
                AppIcons.flagOutlined,
                'Goals',
                () => open(const GoalsScreen()),
              ),
              item(
                AppIcons.personOutlineRounded,
                'Profile',
                () => open(const ProfileScreen()),
              ),
              item(
                AppIcons.settingsOutlined,
                'Settings',
                () => open(const SettingsScreen()),
              ),
              item(
                AppIcons.schoolOutlined,
                'How to use TYF',
                () => open(const HowToScreen()),
              ),
              if (!account.isGuest)
                item(
                  AppIcons.logoutRounded,
                  'Sign out',
                  () => confirmSignOut(context, ref),
                  tint: const Color(0xFFFF6B78),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              // Brand card.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.chartBarRising,
                        color: scheme.primary,
                        size: 34,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TYF',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Color.lerp(
                                  scheme.primary,
                                  const Color(0xFFA78BFA),
                                  0.5,
                                ),
                              ),
                            ),
                            Text(
                              'Track Your Finances. Live Better.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        AppIcons.heartOutline,
                        color: Color.lerp(
                          scheme.primary,
                          const Color(0xFFA78BFA),
                          0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text(
                  _version,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String syncLabel(SyncStatus s) {
  if (s.syncing) return 'Backing up…';
  if (s.error != null) return s.error!;
  final at = s.lastSyncedAt;
  if (at == null) return 'Not backed up yet';
  final ago = DateTime.now().difference(at);
  final when = ago.inMinutes < 1
      ? 'just now'
      : ago.inHours < 1
      ? '${ago.inMinutes} min ago'
      : ago.inDays < 1
      ? '${ago.inHours} h ago'
      : '${ago.inDays} d ago';
  return 'Backed up $when';
}
