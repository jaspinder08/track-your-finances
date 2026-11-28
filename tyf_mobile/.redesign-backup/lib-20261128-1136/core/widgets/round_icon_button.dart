import 'package:flutter/material.dart';

/// Plain icon button used in the top bar: no fill, border or shadow
/// behind the icon, a standard 48×48 target and round ripple.
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
    final button = IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 24,
      color: scheme.onSurface,
    );
    if (badge == null || badge == 0) return button;
    return Badge.count(
      count: badge!,
      backgroundColor: scheme.primary,
      child: button,
    );
  }
}
