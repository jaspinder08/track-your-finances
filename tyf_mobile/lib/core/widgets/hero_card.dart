import 'package:flutter/material.dart';

import '../design/surface.dart';

/// The hero card used at the top of Budgets, Goals, Analytics, and Reports.
///
/// A plain card surface: the same fill, hairline and lift as other cards in
/// light mode, a solid tonal panel in dark mode. No gradient or glow.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Text and icon colour on the card (legacy constant).
  static const foreground = Colors.white;

  /// Theme-adaptive primary foreground colour for text/icons on the card.
  static Color colorOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// Theme-adaptive secondary foreground colour for labels and subtitles.
  static Color dimColorOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.isLight ? Colors.white : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.cardBorder),
        boxShadow: scheme.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
