import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Accent colours the user can pick in Settings.
enum AccentColor {
  // Deep enough for white button text (4.8:1).
  blue('Blue', Color(0xFF2E6BE6)),
  green('Green', Color(0xFF22A861)),
  coral('Coral', Color(0xFFF26B5B)),
  violet('Violet', Color(0xFF7C5CE6)),
  amber('Amber', Color(0xFFF2A007)),
  teal('Teal', Color(0xFF13B3A3)),
  pink('Pink', Color(0xFFE5376B)),
  slate('Slate', Color(0xFF5E7389));

  const AccentColor(this.label, this.color);
  final String label;
  final Color color;
}

/// Colours with a fixed meaning, the same in every accent.
///
/// [income] and [expense] are the bright tones: fills, tints and icons, and
/// text in dark mode. On light surfaces they fall below 4.5:1, so text and
/// small marks there use [incomeOf] / [expenseOf], which switch to a deeper
/// tone (>= 4.9:1 on white and on the light canvas).
class FinanceColors {
  FinanceColors._();
  static const income = Color(0xFF22A861);
  static const expense = Color(0xFFE5484D);

  /// Text-safe tones for light mode.
  static const incomeOnLight = Color(0xFF167A40);
  static const expenseOnLight = Color(0xFFC42F35);

  static bool _light(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  /// Income colour that stays readable on this theme's surfaces.
  static Color incomeOf(BuildContext context) =>
      _light(context) ? incomeOnLight : income;

  /// Expense colour that stays readable on this theme's surfaces.
  static Color expenseOf(BuildContext context) =>
      _light(context) ? expenseOnLight : expense;
}

/// Text colour for content on an accent fill: white when it reaches 4.5:1,
/// otherwise near-black (which passes for every accent in [AccentColor]).
Color onAccent(Color accent) {
  const light = Colors.white;
  const dark = Color(0xFF0A0A0D);
  double ratio(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  final onLight = ratio(light, accent);
  if (onLight >= 4.5) return light;
  final onDark = ratio(dark, accent);
  return onDark >= onLight ? dark : light;
}

/// TYF appearance themes: light and dark, with dynamic accent colours
/// that tint surfaces and backgrounds (see AppBackground).
class AppTheme {
  AppTheme._();

  static const radius = 20.0;

  static ThemeData light(AccentColor accent) {
    const brightness = Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent.color,
      brightness: brightness,
      primary: accent.color,
      onPrimary: onAccent(accent.color),
      // Crisp white and neutral grey surfaces so cards read as clean paper
      // and the accent is used strictly for interactive highlights.
      surface: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF8F9FB),
      surfaceContainer: const Color(0xFFF2F4F7),
      surfaceContainerHigh: const Color(0xFFECEFF3),
      surfaceContainerHighest: const Color(0xFFE6E9EE),
      onSurface: const Color(0xFF151821),
      onSurfaceVariant: const Color(0xFF5D6472),
      outline: const Color(0xFFB9BFCA),
      outlineVariant: const Color(0xFFDDE1E7),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      textTheme: _textTheme(),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: _textTheme().titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: false,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        extendedTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData dark(AccentColor accent) {
    const brightness = Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent.color,
      brightness: brightness,
      primary: accent.color,
      // Readable text on the accent in both themes (M3's dark onPrimary
      // is a dark tint that reads poorly on a saturated accent).
      onPrimary: onAccent(accent.color),
      // Neutral charcoal surfaces without accent wash.
      surface: const Color(0xFF13161E),
      surfaceContainerLow: const Color(0xFF161A23),
      surfaceContainer: const Color(0xFF1B1F2A),
      surfaceContainerHigh: const Color(0xFF212633),
      surfaceContainerHighest: const Color(0xFF282E3D),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      textTheme: _textTheme(),
      // Transparent so AppBackground shows through every page.
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: _textTheme().titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      // Pill-shaped filled segments (Budgets | Goals, Expense | Income),
      // matching the add sheet's type switcher instead of M3's outline.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: false,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        extendedTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Manrope for big numbers, headings and titles; Inter for body text and
/// labels. Numbers use tabular figures so amounts line up in lists.
TextTheme _textTheme() {
  const tab = [FontFeature.tabularFigures()];
  TextStyle m(double size, FontWeight w, {double ls = 0}) => TextStyle(
    fontFamily: 'Manrope',
    fontSize: size,
    fontWeight: w,
    letterSpacing: ls,
    fontFeatures: tab,
  );
  TextStyle i(double size, FontWeight w, {double ls = 0, double? h}) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: w,
        letterSpacing: ls,
        height: h,
        fontFeatures: tab,
      );
  return TextTheme(
    displayLarge: m(57, FontWeight.w800, ls: -1.5),
    displayMedium: m(45, FontWeight.w800, ls: -1),
    displaySmall: m(36, FontWeight.w800, ls: -0.8),
    headlineLarge: m(32, FontWeight.w800, ls: -0.8),
    headlineMedium: m(28, FontWeight.w800, ls: -0.6),
    headlineSmall: m(24, FontWeight.w700, ls: -0.4),
    titleLarge: m(19, FontWeight.w700, ls: -0.3),
    titleMedium: m(16, FontWeight.w700, ls: -0.1),
    titleSmall: m(14, FontWeight.w700),
    bodyLarge: i(16, FontWeight.w400, h: 1.45),
    bodyMedium: i(14, FontWeight.w400, h: 1.45),
    bodySmall: i(12, FontWeight.w400, h: 1.4),
    labelLarge: i(14, FontWeight.w600),
    labelMedium: i(12, FontWeight.w600),
    labelSmall: i(11, FontWeight.w600, ls: 0.2),
  );
}
