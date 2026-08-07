import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Ultra-fluid liquid glass surface with GPU acceleration and zero-GC shadow caching.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 26,
    this.blur = 16,
    this.opacity = 0.42,
    this.tint,
    this.gradient,
    this.borderWidth = 1.0,
    this.borderColor,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? tint;
  final Gradient? gradient;
  final double borderWidth;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.cardBorderColor;
    final baseColor = tint ?? Colors.white;

    // Liquid Glass Refraction Gradient
    final liquidGradient = gradient ??
        LinearGradient(
          colors: [
            baseColor.withValues(alpha: (opacity + 0.25).clamp(0.0, 0.85)),
            Colors.white.withValues(alpha: (opacity * 0.4).clamp(0.0, 0.6)),
            baseColor.withValues(alpha: (opacity + 0.15).clamp(0.0, 0.8)),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    Widget surface = CustomPaint(
      foregroundPainter: _LiquidGlassBevelPainter(
        borderRadius: borderRadius,
        borderWidth: borderWidth,
      ),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          gradient: liquidGradient,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: effectiveBorderColor,
            width: borderWidth,
          ),
          boxShadow: AppColors.glassShadows,
        ),
        child: child,
      ),
    );

    if (onTap != null) {
      surface = GestureDetector(onTap: onTap, child: surface);
    }

    // Isolated inside RepaintBoundary & ClipRRect for 60/120 FPS performance
    return Container(
      margin: margin,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: surface,
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for liquid glass top specular highlight sheen line
class _LiquidGlassBevelPainter extends CustomPainter {
  const _LiquidGlassBevelPainter({
    required this.borderRadius,
    required this.borderWidth,
  });

  final double borderRadius;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final topHighlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.25),
          Colors.transparent,
        ],
        begin: Alignment.topLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, 6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    canvas.drawRRect(rrect, topHighlightPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassBevelPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.borderWidth != borderWidth;
}
