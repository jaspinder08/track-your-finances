import 'package:flutter/material.dart';

/// Card surfaces that suit each theme. Dark mode keeps its translucent
/// tonal panels; light mode uses crisp white cards with a hairline border
/// and a soft shadow, so they lift off the pale canvas instead of
/// blending into it.
extension CardSurface on ColorScheme {
  bool get isLight => brightness == Brightness.light;

  /// Fill for cards and panels. [darkAlpha] is the dark-mode opacity.
  Color cardFill([double darkAlpha = 0.6]) => isLight
      ? Colors.white
      : surfaceContainerHigh.withValues(alpha: darkAlpha);

  /// Hairline around cards.
  Color get cardBorder =>
      isLight ? const Color(0xFFE5E8EE) : outlineVariant.withValues(alpha: 0.2);

  /// Soft lift for cards in light mode; none in dark mode.
  List<BoxShadow> get cardShadow => isLight
      ? const [
          BoxShadow(
            color: Color(0x0D1B2333),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Color(0x0A1B2333),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ]
      : const [];
}
