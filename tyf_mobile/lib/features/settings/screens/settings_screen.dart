import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/shell/app_drawer.dart' show syncLabel;
import '../../../app/shell/top_bar.dart' show hideBalanceProvider;
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/design.dart';
import '../../../core/navigation/page_route.dart';
import '../../account/data/account.dart';
import '../../account/data/csv_export.dart';
import '../../account/screens/sign_in_screen.dart';
import '../../account/screens/sign_out_flow.dart';
import '../../categories/screens/categories_screen.dart';
import '../../help/how_to_screen.dart';
import '../../sync/sync_controller.dart';
import '../../transactions/data/entry_repository.dart';

const _appVersion = '1.0.0';

/// Settings: appearance, data, general and more. Only things that work
/// are listed.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final account = ref.watch(accountProvider);
    final sync = ref.watch(syncProvider);
    final hidden = ref.watch(hideBalanceProvider);

    void push(Widget page) =>
        Navigator.of(context).push(appPageRoute<void>(page));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // ── Appearance ────────────────────────────────────────────
          const _Section(AppIcons.paletteOutlined, 'Appearance'),
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
          _Panel(
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
          const SizedBox(height: 10),
          _Row(
            icon: AppIcons.visibilityOffOutlined,
            color: const Color(0xFF8B7CF6),
            title: 'Hide balance',
            subtitle: 'Show ₹ • • • • • instead of amounts',
            trailing: Switch(
              value: hidden,
              onChanged: (_) => ref.read(hideBalanceProvider.notifier).toggle(),
            ),
            onTap: () => ref.read(hideBalanceProvider.notifier).toggle(),
          ),

          // ── Data ──────────────────────────────────────────────────
          const _Section(AppIcons.databaseOutlined, 'Data'),
          _Row(
            icon: AppIcons.cloudUploadOutlined,
            color: const Color(0xFF3B82F6),
            title: 'Backup',
            subtitle: account.isGuest
                ? 'Sign in to back up your data'
                : syncLabel(sync),
            trailing: !account.isGuest && sync.syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: account.isGuest
                ? () => push(const SignInScreen(mode: SignInMode.voluntary))
                : () => ref.read(syncProvider.notifier).syncNow(),
          ),
          _Row(
            icon: AppIcons.downloadRounded,
            color: const Color(0xFF34C77B),
            title: 'Export to CSV',
            subtitle: 'Open in Excel or Google Sheets',
            onTap: () async {
              final entries = ref.read(entriesProvider).value ?? const [];
              if (entries.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('No transactions to export yet'),
                  ),
                );
                return;
              }
              await shareEntriesCsv(entries);
            },
          ),
          _Row(
            icon: AppIcons.gridViewRounded,
            color: const Color(0xFFE8A93A),
            title: 'Categories',
            subtitle: 'Add, rename and reorder categories',
            onTap: () => push(const CategoriesScreen()),
          ),

          // ── General ───────────────────────────────────────────────
          const _Section(AppIcons.settingsOutlined, 'General'),
          const _Row(
            icon: AppIcons.currencyRupeeRounded,
            color: Color(0xFF2EC4C4),
            title: 'Currency',
            subtitle: 'Indian Rupee (₹ INR)',
            showChevron: false,
          ),

          // ── More ──────────────────────────────────────────────────
          const _Section(AppIcons.starOutline, 'More'),
          _Row(
            icon: AppIcons.schoolOutlined,
            color: const Color(0xFF34C77B),
            title: 'How to use TYF',
            subtitle: 'A quick guide to every feature',
            onTap: () => push(const HowToScreen()),
          ),
          _Row(
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
          _Row(
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

          if (!account.isGuest) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(54),
                foregroundColor: const Color(0xFFFF6B78),
                backgroundColor: FinanceColors.expense.withValues(alpha: 0.08),
                side: BorderSide(
                  color: FinanceColors.expense.withValues(alpha: 0.5),
                ),
              ),
              onPressed: () => confirmSignOut(context, ref),
              icon: const Icon(AppIcons.logoutRounded),
              label: const Text('Log out'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section heading: icon, title, and a faint rule to the edge.
class _Section extends StatelessWidget {
  const _Section(this.icon, this.title);
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 12),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 24),
          const SizedBox(width: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

/// One setting: coloured icon tile, title, subtitle and a chevron.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = true,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.32),
                        color.withValues(alpha: 0.14),
                      ],
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Color.lerp(color, Colors.white, 0.25),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (trailing != null)
                  trailing!
                else if (showChevron && onTap != null)
                  Icon(
                    AppIcons.chevronRightRounded,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
