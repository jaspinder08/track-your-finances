import 'package:flutter/material.dart';

/// Full-screen page route used across the app: slides in from the right.
///
/// Non-opaque on purpose: Riverpod pauses listeners on routes hidden
/// behind an opaque page and resuming them mid-build on close throws when
/// data changed meanwhile (e.g. a goal was edited). Pages using this route
/// paint their own Scaffold background, so it looks the same.
Route<T> appPageRoute<T>(Widget page) => PageRouteBuilder<T>(
  opaque: false,
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 240),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, animation, _, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween(
        begin: const Offset(0.12, 0),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  },
);
