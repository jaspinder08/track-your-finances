import 'package:flutter/material.dart';

import 'tokens.dart';

/// Compact "+ New" pill used in headers. Same accent fill and onPrimary
/// text as the app's main + button and Save buttons, so every "add"
/// action looks alike.
class AddButton extends StatelessWidget {
  const AddButton({
    super.key,
    required this.onPressed,
    this.label = 'New',
    this.tooltip,
  });

  final VoidCallback onPressed;
  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        shape: const StadiumBorder(),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(label),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
