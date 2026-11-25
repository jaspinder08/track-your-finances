import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/account/screens/account_gate.dart';
import '../core/design/app_background.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class TyfApp extends ConsumerWidget {
  const TyfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeControllerProvider);
    return MaterialApp(
      title: 'TYF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(settings.accent),
      themeMode: ThemeMode.dark,
      home: const AppBackground(child: AccountGate()),
    );
  }
}
