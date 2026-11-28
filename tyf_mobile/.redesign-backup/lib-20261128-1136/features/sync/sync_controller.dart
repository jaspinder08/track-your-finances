import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/theme_controller.dart';
import '../../database/database_helper.dart';
import '../budgets/data/budget_repository.dart';
import '../categories/data/category_repository.dart';
import '../transactions/data/entry_repository.dart';
import 'sync_engine.dart';

/// Overridden in main() with Firestore when Firebase is available.
final remoteStoreProvider = Provider<RemoteStore?>((ref) => null);

class SyncStatus {
  const SyncStatus({this.syncing = false, this.lastSyncedAt, this.error});
  final bool syncing;
  final DateTime? lastSyncedAt;
  final String? error;
}

/// Keeps SQLite and the cloud in step for signed-in users: syncs a few
/// seconds after any local change, and when asked (app start, resume,
/// sign-in). Guests never sync.
class SyncController extends Notifier<SyncStatus> {
  static const _kLast = 'sync_last_at';
  static const _debounce = Duration(seconds: 3);

  Timer? _timer;
  Future<SyncResult?>? _running;
  bool _again = false;

  @override
  SyncStatus build() {
    void onChange(Object? _, Object? _) => _schedule();
    ref.listen(entriesProvider, onChange);
    ref.listen(budgetsProvider, onChange);
    ref.listen(categoriesProvider, onChange);
    ref.onDispose(() => _timer?.cancel());
    final last = ref.read(sharedPreferencesProvider)?.getString(_kLast);
    return SyncStatus(lastSyncedAt: last == null ? null : DateTime.parse(last));
  }

  SyncEngine? get _engine {
    final remote = ref.read(remoteStoreProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    if (remote == null || prefs == null || remote.uid == null) return null;
    return SyncEngine(DatabaseHelper.instance, remote, _Prefs(prefs));
  }

  bool get enabled => _engine != null;

  void _schedule() {
    if (!enabled) return;
    _timer?.cancel();
    _timer = Timer(_debounce, syncNow);
  }

  /// Syncs now (or joins the sync already running, then runs once more).
  /// Returns null if not signed in or the sync failed.
  Future<SyncResult?> syncNow() async {
    if (_running != null) {
      _again = true;
      return _running;
    }
    final engine = _engine;
    if (engine == null) return null;
    _timer?.cancel();
    final run = _run(engine);
    _running = run;
    try {
      return await run;
    } finally {
      _running = null;
      if (_again && ref.mounted) {
        _again = false;
        unawaited(syncNow());
      }
    }
  }

  /// Before sign-out: uploads everything. True if nothing is left
  /// un-backed-up (so it's safe to clear this phone).
  Future<bool> backUpForSignOut() async {
    final engine = _engine;
    if (engine == null) return true;
    await syncNow();
    try {
      return await engine.pendingCount() == 0;
    } catch (_) {
      return false;
    }
  }

  /// After sign-out: removes the account's data from this phone.
  Future<void> clearLocal() async {
    _timer?.cancel();
    final remote = ref.read(remoteStoreProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    if (remote != null && prefs != null) {
      await SyncEngine(
        DatabaseHelper.instance,
        remote,
        _Prefs(prefs),
      ).clearLocal();
    }
    await ref.read(sharedPreferencesProvider)?.remove(_kLast);
    ref.invalidate(categoriesProvider);
    ref.invalidate(budgetsProvider);
    ref.invalidate(entriesProvider);
    state = const SyncStatus();
  }

  Future<SyncResult?> _run(SyncEngine engine) async {
    state = SyncStatus(syncing: true, lastSyncedAt: state.lastSyncedAt);
    try {
      final r = await engine.sync();
      if (!ref.mounted) return r;
      if (r.changed > 0) {
        ref.invalidate(categoriesProvider);
        ref.invalidate(budgetsProvider);
        ref.invalidate(entriesProvider);
      }
      final now = DateTime.now();
      await ref
          .read(sharedPreferencesProvider)
          ?.setString(_kLast, now.toIso8601String());
      state = SyncStatus(lastSyncedAt: now);
      return r;
    } catch (_) {
      if (ref.mounted) {
        state = SyncStatus(
          lastSyncedAt: state.lastSyncedAt,
          error: 'Not backed up yet. Will retry when online.',
        );
      }
      return null;
    }
  }
}

final syncProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

class _Prefs implements SyncPrefs {
  _Prefs(this._p);
  final SharedPreferences _p;
  @override
  String? getString(String key) => _p.getString(key);
  @override
  Future<void> setString(String key, String value) => _p.setString(key, value);
  @override
  int? getInt(String key) => _p.getInt(key);
  @override
  Future<void> setInt(String key, int value) => _p.setInt(key, value);
  @override
  Future<void> remove(String key) => _p.remove(key);
}
