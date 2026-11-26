import 'package:flutter/material.dart';

/// The app's backdrop, behind every screen: in dark mode, a deep near-black
/// tinted with the accent; in light mode, a crisp bright canvas tinted softly.
/// Includes soft glows of the accent (and a neighbouring hue) from the
/// corners, and a faint dot grid. Changing the accent in Settings
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
    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.035)
        : Colors.black.withValues(alpha: 0.035);

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
                    isDark ? 0.30 : 0.12,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glow(
                    const Alignment(1.25, 0.15),
                    0.95,
                    partner,
                    isDark ? 0.16 : 0.07,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glow(
                    const Alignment(-0.5, 1.35),
                    0.9,
                    accent,
                    isDark ? 0.12 : 0.05,
                  ),
                ),
              ),
              CustomPaint(painter: _DotGrid(dotColor)),
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
      Color.lerp(const Color(0xFFF7F8FC), accent, 0.02)!;
}

/// A barely-there dot grid that gives the background texture.
class _DotGrid extends CustomPainter {
  const _DotGrid(this.dotColor);

  final Color dotColor;
  static const _gap = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    for (var y = _gap / 2; y < size.height; y += _gap) {
      for (var x = _gap / 2; x < size.width; x += _gap) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGrid oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}
