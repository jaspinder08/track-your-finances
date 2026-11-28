import 'package:flutter/material.dart';

import '../utils/money.dart';

/// How many times the current tab has been opened. Animated widgets key
/// on it, so charts, rings and counters replay each time you switch to a
/// tab (tabs live in an IndexedStack and otherwise animate only once).
class TabVisit extends InheritedWidget {
  const TabVisit({super.key, required this.visits, required super.child});
  final int visits;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabVisit>()?.visits ?? 0;

  @override
  bool updateShouldNotify(TabVisit old) => old.visits != visits;
}

/// A rupee amount that counts up from zero, and glides to new values.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.paise, {super.key, this.style});
  final int paise;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(TabVisit.of(context)),
    tween: Tween(begin: 0, end: paise.toDouble()),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text(Money.format(v.round()), style: style),
  );
}

/// Fades and slides its child up into place, [index] steps after the
/// first, for staggered lists.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, this.index = 0, required this.child});
  final int index;
  final Widget child;

  static const _step = 0.08;

  @override
  Widget build(BuildContext context) {
    final delay = (index * _step).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      key: ValueKey(TabVisit.of(context)),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + (delay * 1000).round()),
      curve: Interval(delay / (0.45 + delay), 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}
