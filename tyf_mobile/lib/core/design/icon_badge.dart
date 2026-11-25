import 'package:flutter/material.dart';

import 'tokens.dart';

/// Rounded, tinted square holding an emoji or an icon: category and
/// payment-method markers, list leading icons, etc.
class IconBadge extends StatelessWidget {
  const IconBadge.emoji(
    String this.emoji, {
    super.key,
    this.size = 44,
    this.color,
  }) : icon = null;

  const IconBadge.icon(
    IconData this.icon, {
    super.key,
    this.size = 44,
    this.color,
  }) : emoji = null;

  final String? emoji;
  final IconData? icon;
  final double size;

  /// Tint; defaults to the accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: emoji != null
          ? Text(emoji!, style: TextStyle(fontSize: size * 0.5, height: 1))
          : Icon(icon, size: size * 0.5, color: c),
    );
  }
}

/// Small rounded status label, e.g. "Over" or "Almost there".
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}
