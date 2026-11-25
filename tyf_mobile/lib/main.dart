import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/theme/theme_controller.dart';
import 'features/account/data/account.dart';
import 'features/account/data/firebase_auth_repository.dart';
import 'features/sync/firestore_remote_store.dart';
import 'features/sync/sync_controller.dart';
import 'features/sync/sync_engine.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TYF is portrait-only: screens are designed for a phone held upright.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  Intl.defaultLocale = 'en_IN';
  await initializeDateFormatting('en_IN');
  final prefs = await SharedPreferences.getInstance();

  // Firebase powers sign-in and sync. If it can't start, the app
  // still works fully offline; sign-in just says it's unavailable.
  AuthRepository auth = const NotConfiguredAuthRepository();
  RemoteStore? remote;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    auth = FirebaseAuthRepository();
    remote = FirestoreRemoteStore();
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(auth),
        remoteStoreProvider.overrideWithValue(remote),
      ],
      child: const TyfApp(),
    ),
  );
}
