import 'package:flutter/material.dart';

/// The app's backdrop, behind every screen: a flat canvas, near-black in
/// dark mode and a pale grey in light mode, each tinted faintly with the
/// accent so changing it in Settings still shifts the mood.
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
    return ColoredBox(color: base, child: child);
  }

  /// The canvas colour in dark mode (also used for system bars).
  static Color backgroundBase(Color accent) =>
      Color.lerp(const Color(0xFF0A0A0F), accent, 0.05)!;

  /// The canvas colour in light mode.
  static Color lightBackgroundBase(Color accent) =>
      Color.lerp(const Color(0xFFF3F4F7), accent, 0.015)!;
}
