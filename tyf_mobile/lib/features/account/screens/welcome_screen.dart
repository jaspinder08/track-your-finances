import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../data/account.dart';
import '../../../core/design/app_icons.dart';

/// First open: brand + what TYF does, then "What should we call you?".
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _askName = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(accountProvider.notifier).completeOnboarding(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_askName,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _askName = false);
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(a),
                child: c,
              ),
            ),
            child: _askName ? _nameStep(context) : _intro(context),
          ),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget feature(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge.icon(icon),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      key: const ValueKey('intro'),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xxl,
        AppSpace.xxxl,
        AppSpace.xxl,
        AppSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const _Wordmark(),
          const SizedBox(height: AppSpace.sm),
          Text(
            'TRACK  YOUR  FINANCES',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 2,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          feature(
            AppIcons.calendarMonthRounded,
            'Every rupee on a calendar',
            'Add an expense in seconds and see your month at a glance.',
          ),
          feature(
            AppIcons.pieChartRounded,
            'Budgets and goals',
            'Set limits per category and save towards what matters.',
          ),
          feature(
            AppIcons.cloudOffRounded,
            'Works offline',
            'Your data lives on your phone. Sign in later to back it up.',
          ),
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: () => setState(() => _askName = true),
            child: const Text('Get started'),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Free for $trialDays days as a guest. No account needed.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameStep(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _form,
      child: Padding(
        key: const ValueKey('name'),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.xxl,
          AppSpace.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => setState(() => _askName = false),
                icon: const Icon(AppIcons.arrowBackRounded),
              ),
            ),
            const SizedBox(height: AppSpace.xxl),
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'What should we call you?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Just your first name is fine.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    maxLength: 30,
                    onFieldSubmitted: (_) => _finish(),
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      prefixIcon: Icon(AppIcons.personOutlineRounded),
                      counterText: '',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Tell us your name'
                        : null,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.sm),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: _finish,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "TYF" with the Y in the accent colour, echoing the logo.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const style = TextStyle(
      fontSize: 72,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: 2,
    );
    return Text.rich(
      TextSpan(
        style: style.copyWith(color: scheme.onSurface),
        children: [
          const TextSpan(text: 'T'),
          TextSpan(
            text: 'Y',
            style: TextStyle(color: scheme.primary),
          ),
          const TextSpan(text: 'F'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
