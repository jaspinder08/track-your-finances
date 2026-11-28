import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'account.dart';

/// Firebase Auth + Firestore implementation of [AuthRepository].
///
/// Guests are Firebase *anonymous* users. Creating an account links an
/// email credential to that same user, so the user ID (and later their
/// synced data) carries over. The trial start lives in
/// `users/{uid}.trialStartedAt` (server time). See
/// docs/auth-and-onboarding.md.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<({DateTime? trialStart, String? email})> ensureGuest({
    DateTime? localTrialStart,
    String? name,
  }) async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
    final doc = _userDoc(user.uid);
    final snap = await doc.get();
    DateTime? server;
    final raw = snap.data()?['trialStartedAt'];
    if (raw is Timestamp) server = raw.toDate();
    if (server == null) {
      // First time this user reaches the server: record the trial start.
      // Use the earlier of "now" and the phone's own start date.
      await doc.set({
        'trialStartedAt': localTrialStart != null
            ? Timestamp.fromDate(localTrialStart)
            : FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'name': ?name,
      }, SetOptions(merge: true));
      server = localTrialStart;
    }
    return (trialStart: server, email: user.isAnonymous ? null : user.email);
  }

  @override
  Future<void> signIn(String email, String password) => _guard(() async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  });

  @override
  Future<void> createAccount(String email, String password) => _guard(() async {
    final cred = EmailAuthProvider.credential(email: email, password: password);
    final current = _auth.currentUser;
    final UserCredential result;
    if (current != null && current.isAnonymous) {
      result = await current.linkWithCredential(cred);
    } else {
      result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
    final user = result.user!;
    await _userDoc(user.uid).set({
      'email': email,
      'upgradedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Non-blocking: they can keep using the app before verifying.
    try {
      await user.sendEmailVerification();
    } catch (_) {}
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));

  bool _googleReady = false;

  @override
  Future<String?> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    final GoogleSignInAccount account;
    try {
      if (!_googleReady) {
        // On Android the web client ID comes from google-services.json.
        await google.initialize();
        _googleReady = true;
      }
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthFailure(
        'Google sign-in didn\'t work (${e.code.name}). '
        'Try again, or use your email instead.',
      );
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthFailure(
        'Google didn\'t return a sign-in token. Try again.',
      );
    }
    final cred = GoogleAuthProvider.credential(idToken: idToken);

    User? user;
    await _guard(() async {
      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) {
        try {
          user = (await current.linkWithCredential(cred)).user;
        } on FirebaseAuthException catch (e) {
          // This Google account already has TYF: sign in to it instead.
          // (This phone's guest data is merged by sync.)
          if (e.code != 'credential-already-in-use' &&
              e.code != 'email-already-in-use') {
            rethrow;
          }
          user = (await _auth.signInWithCredential(e.credential ?? cred)).user;
        }
      } else {
        user = (await _auth.signInWithCredential(cred)).user;
      }
    });
    final email = user?.email ?? account.email;
    await _userDoc(user!.uid).set({
      'email': email,
      'provider': 'google',
      'upgradedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return email;
  }

  @override
  Future<void> signOut() async {
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
    // Back to a fresh guest so the device keeps working.
    try {
      await _auth.signInAnonymously();
    } catch (_) {}
  }

  /// Turns Firebase error codes into messages people understand.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'INVALID_LOGIN_CREDENTIALS' => const AuthFailure(
          'That email and password don\'t match an account.',
          code: AuthFailure.noMatch,
        ),
        'email-already-in-use' ||
        'credential-already-in-use' => const AuthFailure(
          'This email already has a TYF account. Enter its password, '
          'or use "Forgot password?".',
          code: AuthFailure.exists,
        ),
        'invalid-email' => const AuthFailure('That email doesn\'t look right.'),
        'weak-password' => const AuthFailure(
          'Choose a stronger password (at least 8 characters).',
        ),
        'too-many-requests' => const AuthFailure(
          'Too many tries. Wait a few minutes and try again.',
        ),
        'user-disabled' => const AuthFailure('This account has been disabled.'),
        'network-request-failed' => const AuthFailure(
          'No internet connection. Your data is safe on this phone.',
        ),
        'operation-not-allowed' => const AuthFailure(
          'This sign-in method isn\'t switched on in Firebase yet.',
        ),
        'account-exists-with-different-credential' => const AuthFailure(
          'This email already signs in with a password. Use email instead.',
        ),
        _ => AuthFailure('Couldn\'t sign in (${e.code}). Please try again.'),
      };
    }
  }
}
