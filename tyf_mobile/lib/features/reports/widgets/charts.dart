import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/motion.dart';
import '../../../core/utils/money.dart';
import '../data/month_report.dart';

/// Category colours derived from the accent: same saturation and
/// lightness, hue stepped round the wheel, so charts follow the theme.
List<Color> chartPalette(Color accent, int count) {
  final base = HSLColor.fromColor(accent);
  return [
    for (var i = 0; i < count; i++)
      base
          .withHue((base.hue + i * 360 / math.max(count, 1) * 0.85) % 360)
          .withSaturation((base.saturation * 0.9).clamp(0.45, 0.85))
          .withLightness(base.lightness.clamp(0.45, 0.62))
          .toColor(),
  ];
}

/// Animated donut; [selected] slice is pulled out slightly.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.colors,
    required this.center,
    this.selected,
    this.size = 200,
  });
  final List<Slice> slices;
  final List<Color> colors;
  final Widget center;
  final int? selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(
        '${TabVisit.of(context)}${slices.map((s) => '${s.name}${s.paise}').join()}',
      ),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutQuart,
      builder: (context, t, child) => SizedBox.square(
        dimension: size,
        child: Transform.scale(
          scale: 0.85 + 0.15 * t,
          child: CustomPaint(
            painter: _DonutPainter(
              slices.map((s) => s.share).toList(),
              colors,
              t,
              selected,
              Theme.of(context).colorScheme.surface,
            ),
            child: Opacity(opacity: t.clamp(0, 1).toDouble(), child: child),
          ),
        ),
      ),
      child: Center(child: center),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.shares, this.colors, this.t, this.selected, this.gap);
  final List<double> shares;
  final List<Color> colors;
  final double t;
  final int? selected;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 26.0;
    final c = size.center(Offset.zero);
    final radius = size.width / 2 - stroke / 2 - 6;
    var start = -math.pi / 2;
    final total = 2 * math.pi * t;
    for (var i = 0; i < shares.length; i++) {
      final sweep = total * shares[i];
      if (sweep <= 0) continue;
      final isSel = i == selected;
      final mid = start + sweep / 2;
      final shift = isSel
          ? Offset(math.cos(mid), math.sin(mid)) * 6
          : Offset.zero;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? stroke + 6 : stroke;
      // Small gap between slices.
      final gapAngle = shares.length > 1 ? 0.025 : 0.0;
      canvas.drawArc(
        Rect.fromCircle(center: c + shift, radius: radius),
        start + gapAngle / 2,
        math.max(0, sweep - gapAngle),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) =>
      o.t != t || o.selected != selected || o.colors != colors;
}

/// Six-month income (faded) vs expense (accent) bars. Tap a month.
class TrendBars extends StatelessWidget {
  const TrendBars({
    super.key,
    required this.months,
    required this.selected,
    required this.onTap,
  });
  final List<MonthTotals> months;
  final DateTime selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxV = months.fold<int>(
      1,
      (m, e) => math.max(m, math.max(e.income, e.expense)),
    );
    const barMax = 120.0;

    return SizedBox(
      height: barMax + 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in months)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(m.month),
                child: Builder(
                  builder: (context) {
                    final isSel =
                        m.month.year == selected.year &&
                        m.month.month == selected.month;
                    Widget bar(String id, int v, Color color) =>
                        TweenAnimationBuilder<double>(
                          key: ValueKey('$id${TabVisit.of(context)}'),
                          tween: Tween(begin: 0, end: v / maxV * barMax),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, h, _) => Container(
                            width: 10,
                            height: math.max(h, v > 0 ? 3 : 0),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        );
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          m.expense > 0
                              ? Money.compact(m.expense).replaceAll('.0', '')
                              : '',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: isSel
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight: isSel ? FontWeight.w700 : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            bar(
                              'in',
                              m.income,
                              scheme.primary.withValues(
                                alpha: isSel ? 0.35 : 0.18,
                              ),
                            ),
                            const SizedBox(width: 3),
                            bar(
                              'out',
                              m.expense,
                              scheme.primary.withValues(
                                alpha: isSel ? 1 : 0.45,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSel ? scheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            DateFormat.MMM().format(m.month),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSel
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
