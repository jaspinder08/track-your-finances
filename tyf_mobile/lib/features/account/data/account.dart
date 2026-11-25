import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/theme_controller.dart';

/// Length of the guest trial. See docs/auth-and-onboarding.md.
const trialDays = 14;

/// Who's using the app and where they are in the guest trial.
@immutable
class AccountState {
  const AccountState({
    required this.onboarded,
    required this.name,
    required this.trialStartedAt,
    required this.lastPromptDate,
    required this.email,
    this.gateEnabled = true,
  });

  final bool onboarded;
  final String? name;
  final DateTime? trialStartedAt;

  /// Day (yyyy-mm-dd) the daily sign-in screen was last shown.
  final String? lastPromptDate;

  /// Signed-in email; null while a guest.
  final String? email;

  /// False in tests (no device storage): skips onboarding and the gate.
  final bool gateEnabled;

  bool get isGuest => email == null;

  int daysUsed(DateTime now) {
    final start = trialStartedAt ?? now;
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }

  int daysLeft(DateTime now) => (trialDays - daysUsed(now)).clamp(0, trialDays);

  bool trialEnded(DateTime now) => isGuest && daysUsed(now) >= trialDays;

  /// What to show on launch / resume.
  Gate gate(DateTime now) {
    if (!gateEnabled) return Gate.app;
    if (!onboarded) return Gate.welcome;
    if (!isGuest) return Gate.app;
    if (trialEnded(now)) return Gate.locked;
    return lastPromptDate == dayKey(now) ? Gate.app : Gate.dailyPrompt;
  }

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

enum Gate { welcome, dailyPrompt, locked, app }

final accountProvider = NotifierProvider<AccountNotifier, AccountState>(
  AccountNotifier.new,
);

/// Guest/trial state, stored on the phone. When Firebase is connected the
/// trial start will also be saved server-side (see the doc).
class AccountNotifier extends Notifier<AccountState> {
  static const _kOnboarded = 'onboarded';
  static const _kName = 'user_name';
  static const _kTrial = 'trial_started_at';
  static const _kPrompt = 'last_prompt_date';
  static const _kEmail = 'account_email';

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AccountState build() {
    final p = ref.watch(sharedPreferencesProvider);
    if (p == null) {
      return const AccountState(
        onboarded: true,
        name: null,
        trialStartedAt: null,
        lastPromptDate: null,
        email: null,
        gateEnabled: false,
      );
    }
    final trial = p.getString(_kTrial);
    return AccountState(
      onboarded: p.getBool(_kOnboarded) ?? false,
      name: p.getString(_kName),
      trialStartedAt: trial == null ? null : DateTime.tryParse(trial),
      lastPromptDate: p.getString(_kPrompt),
      email: p.getString(_kEmail),
    );
  }

  /// Finishes onboarding: saves the name and starts the trial today.
  /// Marks today as prompted so a new user isn't asked to sign in at once.
  Future<void> completeOnboarding(String name, {DateTime? now}) async {
    final t = now ?? DateTime.now();
    final p = _prefs;
    await p?.setBool(_kOnboarded, true);
    await p?.setString(_kName, name.trim());
    if (p?.getString(_kTrial) == null) {
      await p?.setString(_kTrial, t.toIso8601String());
    }
    await p?.setString(_kPrompt, AccountState.dayKey(t));
    ref.invalidateSelf();
    await syncWithServer();
  }

  /// "Continue as guest" on the daily prompt.
  Future<void> dismissForToday({DateTime? now}) async {
    await _prefs?.setString(
      _kPrompt,
      AccountState.dayKey(now ?? DateTime.now()),
    );
    ref.invalidateSelf();
  }

  /// Called at launch: creates the guest user if needed and adopts the
  /// server's trial start (so changing the phone date can't extend it).
  Future<void> syncWithServer() async {
    final st = state;
    if (!st.gateEnabled || !st.onboarded) return;
    try {
      final r = await ref
          .read(authRepositoryProvider)
          .ensureGuest(localTrialStart: st.trialStartedAt, name: st.name);
      final p = _prefs;
      final server = r.trialStart;
      if (server != null &&
          (st.trialStartedAt == null || server.isBefore(st.trialStartedAt!))) {
        await p?.setString(_kTrial, server.toIso8601String());
      }
      if (r.email != null && st.email != r.email) {
        await p?.setString(_kEmail, r.email!);
      }
      ref.invalidateSelf();
    } catch (_) {
      // Offline or Firebase unavailable: the local trial keeps working.
    }
  }

  Future<void> signedIn(String email) async {
    await _prefs?.setString(_kEmail, email);
    ref.invalidateSelf();
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    await _prefs?.remove(_kEmail);
    ref.invalidateSelf();
  }
}

/// Thrown by [AuthRepository] with a message safe to show the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});
  final String message;

  /// [noMatch]: email/password didn't sign in (wrong password, or no
  /// account yet). [exists]: tried to create an account that exists.
  final String? code;

  static const noMatch = 'no-match';
  static const exists = 'exists';

  @override
  String toString() => message;
}

/// Email + password sign-in. Firebase hides whether an email has an
/// account, so the UI tries [signIn] first and offers [createAccount]
/// when it fails with [AuthFailure.noMatch].
abstract class AuthRepository {
  /// Makes sure this device has a (guest) user, and returns the trial
  /// start saved on the server (earliest of server and [localTrialStart]),
  /// plus the signed-in email if the user already has an account.
  Future<({DateTime? trialStart, String? email})> ensureGuest({
    DateTime? localTrialStart,
    String? name,
  });

  Future<void> signIn(String email, String password);

  /// Upgrades the guest to an email account (same user ID) or creates one.
  Future<void> createAccount(String email, String password);
  Future<void> sendPasswordReset(String email);

  /// Google sign-in. Upgrades the guest in place (same user ID) when the
  /// Google account is new to TYF, otherwise signs in to that account.
  /// Returns the signed-in email, or null if the user cancelled.
  Future<String?> signInWithGoogle();
  Future<void> signOut();
}

/// Used when Firebase isn't available (tests, or init failed): every call
/// fails with a clear message instead of pretending to sign in.
class NotConfiguredAuthRepository implements AuthRepository {
  const NotConfiguredAuthRepository();
  static const _msg =
      'Sign-in isn\'t available right now. Your data is safe on this phone.';
  @override
  Future<({DateTime? trialStart, String? email})> ensureGuest({
    DateTime? localTrialStart,
    String? name,
  }) async => (trialStart: null, email: null);
  @override
  Future<void> signIn(String email, String password) async =>
      throw const AuthFailure(_msg);
  @override
  Future<void> createAccount(String email, String password) async =>
      throw const AuthFailure(_msg);
  @override
  Future<void> sendPasswordReset(String email) async =>
      throw const AuthFailure(_msg);
  @override
  Future<String?> signInWithGoogle() async => throw const AuthFailure(_msg);
  @override
  Future<void> signOut() async {}
}

/// Overridden in main() with the Firebase implementation.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const NotConfiguredAuthRepository(),
);
