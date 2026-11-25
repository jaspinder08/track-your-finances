import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// What the user picked for appearance.
@immutable
class ThemeSettings {
  const ThemeSettings({
    this.mode = ThemeMode.system,
    this.accent = AccentColor.blue,
  });

  final ThemeMode mode;
  final AccentColor accent;

  ThemeSettings copyWith({ThemeMode? mode, AccentColor? accent}) =>
      ThemeSettings(mode: mode ?? this.mode, accent: accent ?? this.accent);
}

/// Device key-value store, loaded in `main()` before the app starts.
/// Null (tests) means settings live in memory only.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Holds theme settings and saves every change so it survives a restart.
class ThemeController extends Notifier<ThemeSettings> {
  static const _modeKey = 'theme_mode';
  static const _accentKey = 'theme_accent';

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return ThemeSettings(
      mode: pick(
        ThemeMode.values,
        prefs?.getString(_modeKey),
        ThemeMode.system,
      ),
      accent: pick(
        AccentColor.values,
        prefs?.getString(_accentKey),
        AccentColor.blue,
      ),
    );
  }

  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    _prefs?.setString(_modeKey, mode.name);
  }

  void setAccent(AccentColor accent) {
    state = state.copyWith(accent: accent);
    _prefs?.setString(_accentKey, accent.name);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);
