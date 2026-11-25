import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../core/design/design.dart';

/// Settings: appearance (accent colour; TYF is always dark) and general
/// options.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpace.lg),
          // Live preview: recolours as soon as a colour is tapped.
          HeroCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: HeroCard.foreground.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        '₹24,500',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: HeroCard.foreground,
                        ),
                      ),
                      Text(
                        'saved this month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: HeroCard.foreground.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: HeroCard.foreground.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    settings.accent.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: HeroCard.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          sectionLabel('Accent colour · changes the whole app'),
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
