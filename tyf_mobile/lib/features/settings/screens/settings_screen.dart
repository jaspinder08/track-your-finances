import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/theme_controller.dart';

/// Settings: appearance (theme mode, accent colour) and general options.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    Widget modeTile(ThemeMode mode, IconData icon, String label) => ListTile(
      leading: Icon(icon),
      title: Text(label, style: theme.textTheme.titleMedium),
      trailing: settings.mode == mode
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: () => controller.setMode(mode),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: theme.textTheme.headlineSmall),
          sectionLabel('Theme'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                modeTile(
                  ThemeMode.system,
                  Icons.brightness_auto_outlined,
                  'Match phone',
                ),
                const Divider(indent: 16, endIndent: 16),
                modeTile(ThemeMode.light, Icons.light_mode_outlined, 'Light'),
                const Divider(indent: 16, endIndent: 16),
                modeTile(ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
              ],
            ),
          ),
          sectionLabel('Accent colour'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final accent in AccentColor.values)
                    Semantics(
                      label: accent.label,
                      selected: accent == settings.accent,
                      button: true,
                      child: GestureDetector(
                        onTap: () => controller.setAccent(accent),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accent.color,
                            shape: BoxShape.circle,
                            border: accent == settings.accent
                                ? Border.all(
                                    color: theme.colorScheme.onSurface,
                                    width: 3,
                                  )
                                : null,
                          ),
                          child: accent == settings.accent
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          sectionLabel('General'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.currency_rupee_rounded),
              title: Text('Currency'),
              subtitle: Text('Indian Rupee (₹ INR)'),
            ),
          ),
        ],
      ),
    );
  }
}
