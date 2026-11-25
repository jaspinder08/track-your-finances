import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tyf_mobile/app/theme/app_theme.dart';
import 'package:tyf_mobile/app/theme/theme_controller.dart';

Future<ProviderContainer> _container() async => ProviderContainer(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(
      await SharedPreferences.getInstance(),
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('theme choices survive a restart', () async {
    final first = await _container();
    first.read(themeControllerProvider.notifier).setAccent(AccentColor.coral);
    first.dispose();

    final second = await _container(); // simulates relaunch
    final s = second.read(themeControllerProvider);
    expect(s.accent, AccentColor.coral);
  });

  test('defaults when nothing is saved or value is unknown', () async {
    SharedPreferences.setMockInitialValues({'theme_accent': 'gone'});
    final s = (await _container()).read(themeControllerProvider);
    expect(s.accent, AccentColor.blue);
  });
}
