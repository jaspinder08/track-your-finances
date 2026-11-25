import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account.dart';

/// Asks, backs up, then signs out. If the backup didn't finish, offers
/// "Sign out anyway". On success pops the current route (the sidebar or
/// the Profile page).
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'Your data is backed up to your account and will be removed from '
        'this phone. Sign in again any time to get it back.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final account = ref.read(accountProvider.notifier);
  if (await account.signOut()) {
    if (context.mounted) Navigator.pop(context); // close the sidebar
    return;
  }
  if (!context.mounted) return;
  // Backup didn't finish (usually no internet).
  final force = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Not backed up yet'),
      content: const Text(
        'Some changes haven\'t reached your account, usually because '
        'there\'s no internet. If you sign out now, they will be lost.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Sign out anyway'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Stay signed in'),
        ),
      ],
    ),
  );
  if (force == true) {
    await account.signOut(force: true);
    if (context.mounted) Navigator.pop(context);
  }
}
