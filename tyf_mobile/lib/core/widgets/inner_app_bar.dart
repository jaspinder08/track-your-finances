import 'package:flutter/material.dart';

import '../design/app_background.dart';

/// The header for every pushed (inner) page: a flat bar in the page's own
/// background colour, the platform back button with a 48×48 target, the
/// title left-aligned next to it, and plain icon buttons for actions.
///
/// It shows a hairline only once content scrolls under it.
class InnerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const InnerAppBar({super.key, this.title, this.actions, this.leading});

  final Widget? title;
  final List<Widget>? actions;

  /// Replaces the back button (rarely needed).
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canvas = theme.brightness == Brightness.dark
        ? AppBackground.backgroundBase(scheme.primary)
        : AppBackground.lightBackgroundBase(scheme.primary);
    return AppBar(
      leading: leading,
      title: title,
      actions: [...?actions, const SizedBox(width: 4)],
      centerTitle: false,
      titleSpacing:
          leading == null && !(ModalRoute.of(context)?.canPop ?? false)
          ? 16
          : 4,
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // Scrolled under: a hairline below the bar, nothing else.
      scrolledUnderElevation: 0.5,
      shadowColor: scheme.outlineVariant,
      foregroundColor: scheme.onSurface,
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
      ),
    );
  }
}
