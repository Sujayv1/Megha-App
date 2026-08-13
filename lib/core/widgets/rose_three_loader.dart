import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_theme.dart';

/// A 60/120 FPS custom painter loading widget rendering the mathematical 3-Petaled Rose curve (Rose Three):
/// r(t) = (9.2 + 0.60s)(0.72 + 0.28s) cos(3t)
/// x(t) = 50 + cos t · r(t) · 3.25
/// y(t) = 50 + sin t · r(t) · 3.25
///
/// Uses an infinite continuous Ticker for zero-jump, perfectly seamless looping.
class RoseThreeLoader extends StatefulWidget {
  const RoseThreeLoader({
    super.key,
    this.size = 180,
    this.color,
    this.glowColor,
    this.particleCount = 76,
  });

  final double size;
  final Color? color;
  final Color? glowColor;
  final int particleCount;

  @override
  State<RoseThreeLoader> createState() => _RoseThreeLoaderState();
}

class _RoseThreeLoaderState extends State<RoseThreeLoader>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final Stopwatch _stopwatch;
  // ValueNotifier drives AnimatedBuilder — only the CustomPaint leaf repaints.
  final _elapsed = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _ticker = createTicker((_) {
      _elapsed.value = _stopwatch.elapsedMilliseconds;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stopwatch.stop();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? AppColors.leafGreen;
    final activeGlow = widget.glowColor ?? AppColors.glowGreen;

    return AnimatedBuilder(
      animation: _elapsed,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _RoseThreePainter(
          elapsedMs: _elapsed.value,
          color: activeColor,
          glowColor: activeGlow,
          particleCount: widget.particleCount,
        ),
      ),
    );
  }
}

class _RoseThreePainter extends CustomPainter {
  _RoseThreePainter({
    required this.elapsedMs,
    required this.color,
    required this.glowColor,
    required this.particleCount,
  });

  final int elapsedMs;
  final Color color;
  final Color glowColor;
  final int particleCount;

  // Math constants matching JS specification
  static const double roseA = 9.2;
  static const double roseABoost = 0.60;
  static const double roseBreathBase = 0.72;
  static const double roseBreathBoost = 0.28;
  static const double roseScale = 3.25;
  static const double trailSpan = 0.31;
  static const int rotationDurationMs = 28000;
  static const int pulseDurationMs = 4400;
  static const int durationMs = 5300;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleFactor = size.width / 100.0;
    final center = Offset(size.width / 2, size.height / 2);

    // Pulse detail scale
    final pulseProgress = (elapsedMs % pulseDurationMs) / pulseDurationMs;
    final pulseAngle = pulseProgress * math.pi * 2;
    final detailScale = 0.52 + ((math.sin(pulseAngle + 0.55) + 1) / 2) * 0.48;

    // Continuous rotation angle
    final rotationAngle =
        -((elapsedMs % rotationDurationMs) / rotationDurationMs) * math.pi * 2;

    // Continuous animation progress along curve
    final animProgress = (elapsedMs % durationMs) / durationMs;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);
    canvas.translate(-center.dx, -center.dy);

    // 1. Draw 3-Petaled Rose background curve path
    final path = Path();
    const steps = 360;
    for (int i = 0; i <= steps; i++) {
      final p = _getPoint(i / steps, detailScale, scaleFactor);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    final curvePaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * scaleFactor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, curvePaint);

    // 2. Draw 76 Trailing Particles along Rose curve
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (int i = particleCount - 1; i >= 0; i--) {
      final tailOffset = i / (particleCount - 1);
      final progress = _normalize(animProgress - tailOffset * trailSpan);
      final point = _getPoint(progress, detailScale, scaleFactor);

      final fade = math.pow(1 - tailOffset, 0.56).toDouble();
      final radius = (0.9 + fade * 2.7) * scaleFactor;
      final opacity = (0.04 + fade * 0.96).clamp(0.0, 1.0);

      final particleColor = Color.lerp(
        color.withValues(alpha: opacity),
        glowColor.withValues(alpha: opacity),
        fade,
      )!;

      particlePaint.color = particleColor;
      canvas.drawCircle(point, radius, particlePaint);
    }

    canvas.restore();
  }

  Offset _getPoint(double progress, double detailScale, double scaleFactor) {
    final t = progress * math.pi * 2;
    final a = roseA + detailScale * roseABoost;
    final r = a *
        (roseBreathBase + detailScale * roseBreathBoost) *
        math.cos(3 * t);

    final x = (50 + math.cos(t) * r * roseScale) * scaleFactor;
    final y = (50 + math.sin(t) * r * roseScale) * scaleFactor;

    return Offset(x, y);
  }

  double _normalize(double progress) {
    return ((progress % 1.0) + 1.0) % 1.0;
  }

  @override
  bool shouldRepaint(covariant _RoseThreePainter oldDelegate) =>
      oldDelegate.elapsedMs != elapsedMs ||
      oldDelegate.color != color ||
      oldDelegate.glowColor != glowColor;
}
