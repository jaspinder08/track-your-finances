import 'package:flutter/material.dart';

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
    final button = Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 24,
      ),
    );
    if (badge == null || badge == 0) return button;
    return Badge.count(
      count: badge!,
      backgroundColor: scheme.primary,
      child: button,
    );
  }
}
