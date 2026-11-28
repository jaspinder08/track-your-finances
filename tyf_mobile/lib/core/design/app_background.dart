import 'package:flutter/material.dart';

/// The app's backdrop, behind every screen: in dark mode, a deep near-black
/// tinted with the accent; in light mode, a crisp bright canvas tinted softly.
/// Includes soft glows of the accent (and a neighbouring hue) from the
/// corners, Changing the accent in Settings
/// changes the whole mood, not just the buttons.
///
/// Scaffolds are transparent (see AppTheme), so pages show this through.
/// Every route paints its own, so pages sliding over each other stay solid.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final hsl = HSLColor.fromColor(accent);
    // A neighbouring hue keeps the glow lively rather than flat.
    final partner = hsl
        .withHue((hsl.hue + 45) % 360)
        .withLightness((hsl.lightness * (isDark ? 0.9 : 1.1)).clamp(0.0, 1.0))
        .toColor();

    RadialGradient glow(Alignment at, double radius, Color c, double a) =>
        RadialGradient(
          center: at,
          radius: radius,
          colors: [
            c.withValues(alpha: a),
            c.withValues(alpha: 0),
          ],
        );

    final base = isDark ? backgroundBase(accent) : lightBackgroundBase(accent);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: base),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glow(
                    const Alignment(-1.1, -1.05),
                    1.15,
                    accent,
                    isDark ? 0.20 : 0.06,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glow(
                    const Alignment(1.25, 0.15),
                    0.95,
                    partner,
                    isDark ? 0.09 : 0.03,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glow(
                    const Alignment(-0.5, 1.35),
                    0.9,
                    accent,
                    isDark ? 0.07 : 0.02,
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }

  /// The base colour under the glows in dark mode (also used for system bars).
  static Color backgroundBase(Color accent) =>
      Color.lerp(const Color(0xFF0A0A0F), accent, 0.05)!;

  /// The base colour under the glows in light mode.
  static Color lightBackgroundBase(Color accent) =>
      Color.lerp(const Color(0xFFF3F4F7), accent, 0.015)!;
}
