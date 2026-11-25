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
    final start = hsl.withSaturation(sat).withLightness(0.50).toColor();
    final end = hsl
        .withHue((hsl.hue + 22) % 360)
        .withSaturation(sat)
        .withLightness(0.34)
        .toColor();
    return (start, end);
  }

  @override
  Widget build(BuildContext context) {
    final (start, end) = colors(Theme.of(context).colorScheme.primary);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
        boxShadow: [
          BoxShadow(
            color: end.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft decorative glows for depth.
          Positioned(
            right: -60,
            top: -70,
            child: _Glow(size: 200, alpha: 0.12),
          ),
          Positioned(
            left: -40,
            bottom: -90,
            child: _Glow(size: 180, alpha: 0.07),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    ),
  );
}
