import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_shell.dart';
import '../data/account.dart';
import 'sign_in_screen.dart';
import 'welcome_screen.dart';

/// Decides what opens: welcome, the daily sign-in prompt, the post-trial
/// lock, or the app. Re-checks when the app comes back to the foreground
/// (so a new day or the end of the trial is noticed).
class AccountGate extends ConsumerStatefulWidget {
  const AccountGate({super.key});

  @override
  ConsumerState<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends ConsumerState<AccountGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(accountProvider.notifier).syncWithServer(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      ref.read(accountProvider.notifier).syncWithServer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(accountProvider).gate(DateTime.now());
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (gate) {
        Gate.welcome => const WelcomeScreen(key: ValueKey('welcome')),
        Gate.dailyPrompt => const SignInScreen(
          key: ValueKey('daily'),
          mode: SignInMode.daily,
        ),
        Gate.locked => const SignInScreen(
          key: ValueKey('locked'),
          mode: SignInMode.locked,
        ),
        Gate.app => const AppShell(key: ValueKey('app')),
      },
    );
  }
}
