import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/app_icons.dart';

/// Friendly placeholder for a screen with nothing in it yet.
///
/// Always centred in the space it's given (vertically and horizontally),
/// and still scrolls if the screen is too short. [bottomInset] keeps it
/// visually centred above the floating nav bar.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.emoji,
    this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon = AppIcons.addRounded,
    this.onAction,
    this.footer,
    this.bottomInset = 96,
  }) : assert(emoji != null || icon != null);

  final String? emoji;
  final IconData? icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  /// Extra content under the button, e.g. quick-start chips.
  final Widget? footer;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.xxl,
          AppSpace.lg,
          AppSpace.xxl,
          bottomInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (box.maxHeight - AppSpace.lg - bottomInset).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.08),
                  ),
                  child: emoji != null
                      ? Text(
                          emoji!,
                          style: const TextStyle(fontSize: 34, height: 1),
                        )
                      : Icon(icon, size: 32, color: scheme.primary),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpace.xxl),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: onAction,
                    icon: Icon(actionIcon),
                    label: Text(actionLabel!),
                  ),
                ],
                if (footer != null) ...[
                  const SizedBox(height: AppSpace.xl),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
