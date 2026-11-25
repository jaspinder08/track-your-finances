import 'package:flutter/material.dart';

/// The accent "hero" card used at the top of Budgets, Goals and Reports.
///
/// The gradient is built from the accent's hue at fixed, deep lightness,
/// so white text stays readable in both light and dark themes (the dark
/// theme's `primary` is too light for white text, and its `onPrimary`
/// is a dark navy that reads poorly on a gradient).
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Text and icon colour on the card.
  static const foreground = Colors.white;

  static (Color, Color) colors(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    final sat = hsl.saturation.clamp(0.55, 0.85).toDouble();
    // Deep, accent-tinted glass: rich enough to stand out, dark enough
    // to sit inside the glowing dark background instead of on top of it.
    final start = hsl.withSaturation(sat).withLightness(0.30).toColor();
    final end = hsl
        .withHue((hsl.hue + 35) % 360)
        .withSaturation(sat * 0.8)
        .withLightness(0.13)
        .toColor();
    return (start, end);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final (start, end) = colors(accent);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        // A soft, centred accent glow; no offset shadow (that reads as a
        // dark strip under the card).
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 32,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft decorative glows for depth.
          Positioned(
            right: -60,
            top: -70,
            child: _Glow(size: 220, color: accent, alpha: 0.35),
          ),
          Positioned(
            left: -40,
            bottom: -90,
            child: _Glow(size: 180, color: Colors.white, alpha: 0.05),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.alpha});
  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}
