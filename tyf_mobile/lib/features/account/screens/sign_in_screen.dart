import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../transactions/data/entry_repository.dart';
import '../data/account.dart';
import '../data/csv_export.dart';
import '../../onboarding/setup_sheet.dart';

/// Why the sign-in screen is showing.
enum SignInMode {
  /// First open of the day during the trial; can continue as guest.
  daily,

  /// Trial over: can't be dismissed (export is still allowed).
  locked,

  /// Opened from the sidebar; normal back navigation.
  voluntary,
}

/// One screen for sign in and sign up: enter email, then TYF works out
/// whether to ask for the password or to create one.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, required this.mode});
  final SignInMode mode;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

enum _Step { email, password }

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Step _step = _Step.email;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _info;

  /// Sign-in failed with "no match": offer to create an account instead.
  bool _offerCreate = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
      _offerCreate = false;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _offerCreate = e.code == AuthFailure.noMatch;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Something went wrong. Check your internet and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    if (_step == _Step.email) {
      setState(() {
        _step = _Step.password;
        _error = null;
      });
      return;
    }
    await _run(() async {
      await ref.read(authRepositoryProvider).signIn(email, _password.text);
      await _done(email);
    });
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .createAccount(email, _password.text);
      await _done(email);
    });
  }

  Future<void> _done(String email) async {
    final setup = ref.read(setupPromptProvider.notifier);
    await ref.read(accountProvider.notifier).signedIn(email);
    if (mounted && widget.mode == SignInMode.voluntary) Navigator.pop(context);
    // Shown by the app shell once it's on screen again.
    setup.request();
  }

  Future<void> _google() async {
    await _run(() async {
      final email = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (email != null) await _done(email);
    });
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    await _run(() async {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      setState(() => _info = 'We sent a reset link to $email.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final account = ref.watch(accountProvider);
    final now = DateTime.now();
    final locked = widget.mode == SignInMode.locked;
    final entryCount = (ref.watch(entriesProvider).value ?? const []).length;

    final (title, subtitle) = switch (widget.mode) {
      SignInMode.locked => (
        'Your free trial has ended',
        'Create a free account to keep using TYF. '
            '${entryCount == 0 ? 'Your data' : 'Your $entryCount entries'} '
            'are safe on this phone and will be saved to your account.',
      ),
      SignInMode.daily => (
        'Hi${account.name == null ? '' : ', ${account.name}'}! Back up your data',
        'Create a free account so your entries are safe if you change phones.',
      ),
      SignInMode.voluntary => (
        'Sign in to TYF',
        'Back up your data and use TYF on more than one phone.',
      ),
    };

    final content = Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xxl,
          AppSpace.lg,
          AppSpace.xxl,
          AppSpace.xxl,
        ),
        children: [
          if (widget.mode != SignInMode.voluntary) ...[
            const SizedBox(height: AppSpace.xxl),
            IconBadge.icon(
              locked ? Icons.lock_clock_rounded : Icons.cloud_done_rounded,
              size: 64,
            ),
            const SizedBox(height: AppSpace.xl),
          ],
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (widget.mode == SignInMode.daily) ...[
            const SizedBox(height: AppSpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(
                '${account.daysLeft(now)} days left in your free trial',
                color: scheme.primary,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.xxl),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: _busy ? null : _google,
            icon: const _GoogleMark(),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                child: Text(
                  'or use email',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          TextFormField(
            controller: _email,
            enabled: _step == _Step.email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _continue(),
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              suffixIcon: _step == _Step.email
                  ? null
                  : TextButton(
                      onPressed: () => setState(() {
                        _step = _Step.email;
                        _password.clear();
                        _error = null;
                      }),
                      child: const Text('Change'),
                    ),
            ),
            validator: (v) => _emailRe.hasMatch(v?.trim() ?? '')
                ? null
                : 'Enter a valid email, e.g. name@gmail.com',
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: _step == _Step.email
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpace.md),
                    child: TextFormField(
                      controller: _password,
                      autofocus: true,
                      obscureText: !_showPassword,
                      autofillHints: [AutofillHints.password],
                      onFieldSubmitted: (_) => _continue(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText:
                            'New here? Choose one, at least 8 characters',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < 8
                          ? 'Use at least 8 characters'
                          : null,
                    ),
                  ),
          ),
          if (_step == _Step.password)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _forgot,
                child: const Text('Forgot password?'),
              ),
            ),
          if (_error != null || _info != null) ...[
            const SizedBox(height: AppSpace.md),
            AppCard(
              tint: _error != null ? scheme.error : scheme.primary,
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _error != null
                        ? Icons.info_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 20,
                    color: _error != null ? scheme.error : scheme.primary,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text(_error ?? _info!)),
                ],
              ),
            ),
            if (_offerCreate) ...[
              const SizedBox(height: AppSpace.md),
              Text(
                'New to TYF?',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _busy ? null : _create,
                child: Text('Create account with ${_email.text.trim()}'),
              ),
            ],
          ],
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: _busy ? null : _continue,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Continue'),
          ),
          if (widget.mode == SignInMode.daily) ...[
            const SizedBox(height: AppSpace.sm),
            TextButton(
              onPressed: () =>
                  ref.read(accountProvider.notifier).dismissForToday(),
              child: Text(
                'Continue as guest · ${account.daysLeft(now)} days left',
              ),
            ),
          ],
          if (locked) ...[
            const SizedBox(height: AppSpace.sm),
            TextButton.icon(
              onPressed: entryCount == 0
                  ? null
                  : () => shareEntriesCsv(
                      ref.read(entriesProvider).value ?? const [],
                    ),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export my data (CSV)'),
            ),
          ],
        ],
      ),
    );

    return PopScope(
      // Locked: back can't skip sign-in (Android back leaves the app).
      canPop: !locked,
      child: Scaffold(
        appBar: widget.mode == SignInMode.voluntary ? AppBar() : null,
        body: SafeArea(child: content),
      ),
    );
  }
}

/// The multicolour "G", drawn so no image asset is needed.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CustomPaint(painter: _GPainter()),
  );
}

class _GPainter extends CustomPainter {
  const _GPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.2;
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    Paint p(int c) => Paint()
      ..color = Color(c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    const d = 3.14159265 / 180;
    canvas.drawArc(rect, -40 * d, -100 * d, false, p(0xFFEA4335)); // red
    canvas.drawArc(rect, -140 * d, -90 * d, false, p(0xFFFBBC05)); // yellow
    canvas.drawArc(rect, 130 * d, -90 * d, false, p(0xFF34A853)); // green
    canvas.drawArc(rect, 40 * d, -40 * d, false, p(0xFF4285F4)); // blue
    final c = size.center(Offset.zero);
    canvas.drawLine(c, Offset(size.width - w / 2, c.dy), p(0xFF4285F4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
