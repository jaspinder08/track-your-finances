import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/design.dart';
import '../../../core/navigation/page_route.dart';
import '../../../core/widgets/option_row.dart';
import '../../help/how_to_screen.dart';
import '../../support/support.dart';
import '../../notifications/notifications.dart';

const _appVersion = '1.0.0';

/// Settings: appearance, data, notifications, general and more.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final notif = ref.watch(notificationPrefsProvider);
    final notifCtl = ref.read(notificationPrefsProvider.notifier);

    void toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)),
    );
    const denied =
        'Notifications are off for TYF. Allow them in the phone\'s settings.';

    void push(Widget page) =>
        Navigator.of(context).push(appPageRoute<void>(page));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // ── Appearance ────────────────────────────────────────────
          const OptionSection(AppIcons.paletteOutlined, 'Appearance'),
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
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: HeroCard.foreground.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(100),
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
          const SizedBox(height: 10),
          OptionPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Accent colour', style: theme.textTheme.titleSmall),
                Text(
                  'Changes the whole app',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final accent in AccentColor.values)
                      Semantics(
                        label: accent.label,
                        selected: accent == settings.accent,
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.setAccent(accent);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: accent.color,
                              shape: BoxShape.circle,
                              border: accent == settings.accent
                                  ? Border.all(
                                      color: scheme.onSurface,
                                      width: 3,
                                    )
                                  : null,
                              boxShadow: [
                                if (accent == settings.accent)
                                  BoxShadow(
                                    color: accent.color.withValues(alpha: 0.5),
                                    blurRadius: 14,
                                    spreadRadius: -2,
                                  ),
                              ],
                            ),
                            child: accent == settings.accent
                                ? const Icon(
                                    AppIcons.checkRounded,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Notifications ─────────────────────────────────────────
          const OptionSection(
            AppIcons.notificationsActiveOutlined,
            'Notifications',
          ),
          OptionRow(
            icon: AppIcons.bellRinging,
            color: const Color(0xFF8B7CF6),
            title: 'Daily reminder',
            subtitle: notif.dailyReminder
                ? 'Every day at ${notif.reminderTime.format(context)}'
                : 'A nudge to note the day\'s spending',
            trailing: Switch(
              value: notif.dailyReminder,
              onChanged: (v) async {
                if (!await notifCtl.setDailyReminder(v)) toast(denied);
              },
            ),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: notif.reminderTime,
                helpText: 'Remind me at',
              );
              if (t == null) return;
              await notifCtl.setReminderTime(t);
              if (!notif.dailyReminder &&
                  !await notifCtl.setDailyReminder(true)) {
                toast(denied);
              }
            },
          ),
          OptionRow(
            icon: AppIcons.pieChartRounded,
            color: const Color(0xFFE8A93A),
            title: 'Budget alerts',
            subtitle: 'When a budget reaches 80% or goes over',
            trailing: Switch(
              value: notif.budgetAlerts,
              onChanged: (v) async {
                if (!await notifCtl.setBudgetAlerts(v)) toast(denied);
              },
            ),
            onTap: () async {
              if (!await notifCtl.setBudgetAlerts(!notif.budgetAlerts)) {
                toast(denied);
              }
            },
          ),

          // ── General ───────────────────────────────────────────────
          const OptionSection(AppIcons.settingsOutlined, 'General'),
          const OptionRow(
            icon: AppIcons.currencyRupeeRounded,
            color: Color(0xFF2EC4C4),
            title: 'Currency',
            subtitle: 'Indian Rupee (₹ INR)',
            showChevron: false,
          ),

          // ── More ──────────────────────────────────────────────────
          const OptionSection(AppIcons.starOutline, 'More'),
          OptionRow(
            icon: AppIcons.schoolOutlined,
            color: const Color(0xFF34C77B),
            title: 'How to use TYF',
            subtitle: 'A quick guide to every feature',
            onTap: () => push(const HowToScreen()),
          ),
          OptionRow(
            icon: AppIcons.starOutline,
            color: const Color(0xFFE8A93A),
            title: 'Rate TYF',
            subtitle: 'Enjoying TYF? Leave a review',
            onTap: () async {
              if (!await openStoreListing()) toast('Couldn\'t open the store');
            },
          ),
          OptionRow(
            icon: AppIcons.chatCircle,
            color: const Color(0xFF8B7CF6),
            title: 'Feedback',
            subtitle: 'Send a suggestion or report a bug',
            onTap: () => _feedback(context),
          ),
          OptionRow(
            icon: AppIcons.shareNetwork,
            color: const Color(0xFF5B8DEF),
            title: 'Recommend TYF',
            subtitle: 'Share TYF with friends',
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text:
                    'I track my money with TYF – Track Your Finances. '
                    'Simple budgets, insights and backup. Give it a try!',
              ),
            ),
          ),
          OptionRow(
            icon: AppIcons.infoOutlineRounded,
            color: const Color(0xFF8B7CF6),
            title: 'About TYF',
            subtitle: 'Version $_appVersion · Made with ❤️ in India',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'TYF',
              applicationVersion: _appVersion,
              applicationLegalese: 'Track Your Finances. Live Better.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Feedback or bug report, sent by email.
Future<void> _feedback(BuildContext context) async {
  final kind = await showModalBottomSheet<FeedbackKind>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(AppIcons.chatCircle),
            title: const Text('Send feedback'),
            subtitle: const Text('Ideas, suggestions, what you like'),
            onTap: () => Navigator.pop(c, FeedbackKind.feedback),
          ),
          ListTile(
            leading: const Icon(AppIcons.bug),
            title: const Text('Report a bug'),
            subtitle: const Text('Includes app version and phone model'),
            onTap: () => Navigator.pop(c, FeedbackKind.bug),
          ),
        ],
      ),
    ),
  );
  if (kind == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (!await sendFeedback(kind)) {
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('No email app found. Write to $supportEmail'),
      ),
    );
  }
}
