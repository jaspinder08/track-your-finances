import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// What the user picked for appearance: accent colour and theme mode.
@immutable
class ThemeSettings {
  const ThemeSettings({
    this.accent = AccentColor.blue,
    this.mode = ThemeMode.system,
  });

  final AccentColor accent;
  final ThemeMode mode;
}

/// Device key-value store, loaded in `main()` before the app starts.
/// Null (tests) means settings live in memory only.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Holds theme settings and saves every change so it survives a restart.
class ThemeController extends Notifier<ThemeSettings> {
  static const _accentKey = 'theme_accent';
  static const _modeKey = 'theme_mode';

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return ThemeSettings(
      accent: pick(
        AccentColor.values,
        prefs?.getString(_accentKey),
        AccentColor.blue,
      ),
      mode: pick(
        ThemeMode.values,
        prefs?.getString(_modeKey),
        ThemeMode.system,
      ),
    );
  }

  void setAccent(AccentColor accent) {
    state = ThemeSettings(accent: accent, mode: state.mode);
    _prefs?.setString(_accentKey, accent.name);
  }

  void setMode(ThemeMode mode) {
    state = ThemeSettings(accent: state.accent, mode: mode);
    _prefs?.setString(_modeKey, mode.name);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);
