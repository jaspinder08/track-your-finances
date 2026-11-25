import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sync/sync_controller.dart';

import '../../core/design/design.dart';
import '../../core/navigation/page_route.dart';
import '../../features/account/data/account.dart';
import '../../features/account/screens/sign_in_screen.dart';
import '../../features/account/screens/sign_out_flow.dart';
import '../../features/account/screens/profile_screen.dart';
import '../../features/help/how_to_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

/// Side menu: greeting, account card, and secondary pages.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = ref.watch(accountProvider);

    Widget item(IconData icon, String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label, style: theme.textTheme.titleMedium),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        onTap: onTap,
      ),
    );

    void open(Widget page) {
      Navigator.of(context)
        ..pop()
        ..push(appPageRoute<void>(page));
    }

    final sync = ref.watch(syncProvider);
    return Drawer(
      // The app's own glowing background, so the sidebar isn't a flat slab.
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Text(
                  account.name == null || account.name!.isEmpty
                      ? 'Hello there'
                      : 'Hello, ${account.name}',
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      IconBadge.icon(
                        account.isGuest
                            ? Icons.person_outline_rounded
                            : Icons.verified_user_outlined,
                        size: 40,
                      ),
                      const SizedBox(width: AppSpace.md),
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
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (!account.isGuest)
                              Text(
                                syncLabel(sync),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: sync.error != null
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
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
                              : () => ref.read(syncProvider.notifier).syncNow(),
                          icon: sync.syncing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_sync_outlined),
                        ),
                    ],
                  ),
                ),
              ),
              if (account.isGuest)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: () =>
                        open(const SignInScreen(mode: SignInMode.voluntary)),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                    label: const Text('Sign in to back up'),
                  ),
                ),
              const Divider(),
              const SizedBox(height: 8),
              item(
                Icons.flag_outlined,
                'Goals',
                () => open(const GoalsScreen()),
              ),
              item(
                Icons.person_outline_rounded,
                'Profile',
                () => open(const ProfileScreen()),
              ),
              item(
                Icons.settings_outlined,
                'Settings',
                () => open(const SettingsScreen()),
              ),
              item(
                Icons.school_outlined,
                'How to use TYF',
                () => open(const HowToScreen()),
              ),
              if (!account.isGuest)
                item(
                  Icons.logout_rounded,
                  'Sign out',
                  () => confirmSignOut(context, ref),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'TYF · Track Your Finances',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
