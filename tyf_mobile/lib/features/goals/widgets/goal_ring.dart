import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/motion.dart';

/// Animated circular progress with content in the middle.
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.ratio,
    required this.color,
    required this.size,
    this.stroke = 8,
    this.trackColor,
    this.child,
  });
  final double ratio;
  final Color color;
  final double size;
  final double stroke;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(TabVisit.of(context)),
    tween: Tween(begin: 0, end: ratio.clamp(0, 1).toDouble()),
    duration: const Duration(milliseconds: 800),
    curve: Curves.easeOutCubic,
    builder: (context, v, child) => SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          v,
          color,
          trackColor ?? color.withValues(alpha: 0.16),
          stroke,
        ),
        child: child,
      ),
    ),
    child: Center(child: child),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track, this.stroke);
  final double v;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (v > 0) {
      canvas.drawArc(
        r,
        -math.pi / 2,
        2 * math.pi * v,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color;
}
