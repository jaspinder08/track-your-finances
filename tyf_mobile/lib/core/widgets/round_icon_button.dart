import 'package:flutter/material.dart';

import '../design/surface.dart';

/// Soft circular button used in the top bar.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.isLight;
    final button = Material(
      color: light
          ? Colors.white
          : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: light
          ? CircleBorder(side: BorderSide(color: scheme.cardBorder))
          : const CircleBorder(),

      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 24,
        style: IconButton.styleFrom(shape: const CircleBorder()),
      ),
    );
    final lifted = light
        ? DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: scheme.cardShadow,
            ),
            child: button,
          )
        : button;
    if (badge == null || badge == 0) return lifted;
    return Badge.count(
      count: badge!,
      backgroundColor: scheme.primary,
      child: lifted,
    );
  }
}
