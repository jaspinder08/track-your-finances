/// Spacing scale. Use these instead of raw numbers so screens line up.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Bottom padding for scrolling tab content, so it clears the
  /// floating nav bar.
  static const double navBarClearance = 120;
}

/// Corner radius scale.
abstract final class AppRadius {
  // Tight corners: slightly softened, never pill-shaped.
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 8;

  /// Standard cards and panels.
  static const double card = 10;

  /// Hero cards and bottom sheets.
  static const double hero = 12;
}
