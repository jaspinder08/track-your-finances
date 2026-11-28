import 'package:flutter/material.dart';

/// The app's backdrop, behind every screen: a flat neutral canvas, deep
/// charcoal in dark mode and a pale off-white in light mode.
///
/// Scaffolds are transparent (see AppTheme), so pages show this through.
/// Every route paints its own, so pages sliding over each other stay solid.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final base = theme.brightness == Brightness.dark
        ? backgroundBase(accent)
        : lightBackgroundBase(accent);
    return AnimatedContainer(
      duration: kThemeAnimationDuration,
      curve: Curves.easeOut,
      color: base,
      child: child,
    );
  }

  /// The canvas colour in dark mode (also used for system bars).
  static Color backgroundBase(Color accent) => const Color(0xFF0D0F14);

  /// The canvas colour in light mode.
  static Color lightBackgroundBase(Color accent) => const Color(0xFFF5F6FA);
}
