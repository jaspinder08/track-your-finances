import 'package:flutter/material.dart';

/// The hero card used at the top of Budgets, Goals, Analytics, and Reports.
///
/// Adapts seamlessly to both light and dark themes using the same surface-gradient
/// and border style as [_SpendingByCategory] / [_Panel], tinted softly with the
/// active accent color.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = scheme.primary;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.75 : 0.85),
            Color.lerp(
              scheme.surfaceContainerHigh,
              accent,
              isDark ? 0.08 : 0.07,
            )!.withValues(alpha: isDark ? 0.75 : 0.85),
          ],
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? accent.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft decorative glows for depth.
          Positioned(
            right: -60,
            top: -70,
            child: _Glow(
              size: 220,
              color: accent,
              alpha: isDark ? 0.25 : 0.08,
            ),
          ),
          Positioned(
            left: -40,
            bottom: -90,
            child: _Glow(
              size: 180,
              color: isDark ? Colors.white : accent,
              alpha: isDark ? 0.05 : 0.04,
            ),
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
