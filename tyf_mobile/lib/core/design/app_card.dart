import 'package:flutter/material.dart';

import 'surface.dart';
import 'tokens.dart';

/// The standard surface card: soft fill, hairline border, rounded corners.
/// Pass [onTap] to make it tappable (with ink ripple clipped to the shape),
/// or [tint] for an accent-tinted variant.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
    this.tint,
    this.radius = AppRadius.card,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border && tint == null
          ? BorderSide(color: scheme.cardBorder)
          : BorderSide.none,
    );
    final material = Material(
      color:
          tint?.withValues(alpha: 0.12) ??
          (scheme.isLight
              ? Colors.white
              : scheme.surfaceContainerHighest.withValues(alpha: 0.4)),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (tint != null || !scheme.isLight) return material;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: scheme.cardShadow,
      ),
      child: material,
    );
  }
}
