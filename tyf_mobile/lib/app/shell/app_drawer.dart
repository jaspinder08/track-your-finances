import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/navigation/page_route.dart';
import '../../features/account/data/account.dart';
import '../../features/account/screens/sign_in_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../theme/theme_controller.dart';

/// Side menu: greeting, quick dark-mode switch, and secondary pages.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final account = ref.watch(accountProvider);

    Widget item(IconData icon, String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label, style: theme.textTheme.titleMedium),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

    return Drawer(
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
                        ],
                      ),
                    ),
                    if (account.isGuest)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => open(
                          const SignInScreen(mode: SignInMode.voluntary),
                        ),
                        child: const Text('Sign in'),
                      ),
                  ],
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: Text('Dark mode', style: theme.textTheme.titleMedium),
              value: isDark,
              onChanged: (on) => ref
                  .read(themeControllerProvider.notifier)
                  .setMode(on ? ThemeMode.dark : ThemeMode.light),
            ),
            const Divider(),
            const SizedBox(height: 8),
            item(Icons.flag_outlined, 'Goals', () => open(const GoalsScreen())),
            item(
              Icons.person_outline_rounded,
              'Profile',
              () => Navigator.pop(context),
            ),
            item(
              Icons.settings_outlined,
              'Settings',
              () => open(const SettingsScreen()),
            ),
            item(
              Icons.school_outlined,
              'How to use TYF',
              () => Navigator.pop(context),
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
    );
  }
}
